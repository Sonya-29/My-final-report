
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Import this to use Ownable
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; // For uri function (optional, but good for ERC1155 metadata)

contract CarbonCredit is ERC1155, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256; // For converting uint256 to string in uri

    // --- Enum để quản lý trạng thái dự án ---
    enum ProjectStatus {
        Pending,        // Đang chờ xác minh ban đầu
        Validated,      // Đã được xác minh và có thể phát hành tín chỉ
        Challenged,     // Đang bị tranh chấp, cần giải quyết
        Invalidated     // Đã bị vô hiệu hóa (do challenge thành công hoặc lý do khác)
    }

    struct ProjectInfo {
        string name;
        string description;
        string location;
        string dataHash;           // Hash hoặc link dữ liệu dự án (ảnh vệ tinh, LiDAR, AI analysis)
        address uploader;          // Địa chỉ của người/tổ chức tải lên dự án
        uint256 totalMinted;       // Tổng số tín chỉ đã được mint cho dự án này
        uint256 totalBurned;       // Tổng số tín chỉ đã được burn từ dự án này
        ProjectStatus status;      // Trạng thái hiện tại của dự án (thay thế validated, challenged)
        uint confirmCount;      // Số lượng validator đã xác nhận
        uint challengeCount;    // Số lượng validator đã thách thức
        uint256 creationTime;      // Thời điểm tạo dự án, dùng cho timeout
    }

    Counters.Counter private _projectIdCounter;
    mapping(uint256 => ProjectInfo) public projects;
    mapping(address => bool) public validators;
    mapping(uint256 => mapping(address => bool)) public validatorConfirmed;
    mapping(uint256 => mapping(address => bool)) public validatorChallenged;
    // Bỏ userBalances mapping đi, dùng trực tiếp balanceOf của ERC1155

    IERC20 public rewardToken; // Token ERC20 dùng để thưởng

    uint256 public constant MIN_VALIDATORS_FOR_CONFIRM = 2; // Số validator tối thiểu để xác nhận
    uint256 public constant VALIDATION_PERIOD_SECONDS = 7 days; // Thời gian cho phép xác minh/thách thức

    // --- Events (Sự kiện) ---
    event ProjectCreated(uint256 indexed id, string name, address indexed uploader, string dataHash);
    event ValidatorConfirmed(uint256 indexed projectId, address indexed validator);
    event ValidatorChallenged(uint256 indexed projectId, address indexed validator);
    event ProjectStatusUpdated(uint256 indexed projectId, ProjectStatus oldStatus, ProjectStatus newStatus, address indexed caller);
    event CarbonCreditsMinted(uint256 indexed projectId, address indexed to, uint256 amount);
    event CarbonCreditsBurned(uint256 indexed projectId, address indexed from, uint256 amount);
    event ValidationRewarded(address indexed validator, uint256 amount);

    // --- Modifiers ---
    modifier onlyValidator() {
        require(validators[msg.sender], "Not a validator");
        _;
    }

    // --- Constructor ---
    // Constructor của ERC1155 cần một base URI cho metadata của token.
    // VD: "https://my-api.com/token/" (sẽ nối thêm ID của token)
    // Thêm _initialOwner để truyền cho Ownable
    constructor(string memory uri_, address _rewardTokenAddress, address _initialOwner)
        ERC1155(uri_)
        Ownable(_initialOwner) // Truyền _initialOwner cho constructor của Ownable
    {
        // Người triển khai hợp đồng (owner) cũng được thêm làm validator mặc định
        validators[msg.sender] = true;
        // Gán địa chỉ token thưởng
        rewardToken = IERC20(_rewardTokenAddress);
    }

    // --- Chức năng quản lý Validator (chỉ chủ sở hữu hợp đồng) ---
    function addValidator(address _validatorAddress) public onlyOwner {
        require(!validators[_validatorAddress], "Already a validator");
        validators[_validatorAddress] = true;
    }

    function removeValidator(address _validatorAddress) public onlyOwner {
        require(validators[_validatorAddress], "Not a validator");
        // Sử dụng owner() từ Ownable để kiểm tra người sở hữu hiện tại của hợp đồng
        require(_validatorAddress != owner(), "Cannot remove contract owner as validator");
        validators[_validatorAddress] = false;
    }

    // --- Chức năng chính của OFP ---

    /**
     * @dev 1. Đăng ký một dự án rừng mới và tải lên dữ liệu ban đầu.
     * Yêu cầu phí để đăng ký. Trả về Project ID mới được tạo.
     * @param _name Tên dự án.
     * @param _description Mô tả dự án.
     * @param _location Vị trí địa lý của dự án.
     * @param _dataHash Hash/link đến dữ liệu chi tiết của dự án (ví dụ: IPFS hash của báo cáo vệ tinh).
     */
    function createProject(
        string memory _name,
        string memory _description,
        string memory _location,
        string memory _dataHash
    ) public payable returns (uint256 newProjectId) {
        // Phí tối thiểu để tạo dự án (ví dụ: 0.01 ETH)
        require(msg.value >= 0.01 ether, "Insufficient fee to create project (min 0.01 ETH)");

        _projectIdCounter.increment();
        newProjectId = _projectIdCounter.current();

        projects[newProjectId] = ProjectInfo({
            name: _name,
            description: _description,
            location: _location,
            dataHash: _dataHash,
            uploader: msg.sender,
            totalMinted: 0,
            totalBurned: 0,
            status: ProjectStatus.Pending, // Trạng thái ban đầu
            confirmCount: 0,
            challengeCount: 0,
            creationTime: block.timestamp // Ghi lại thời gian tạo để tính timeout
        });

        emit ProjectCreated(newProjectId, _name, msg.sender, _dataHash);
    }

    /**
     * @dev 2. Validator xác nhận dữ liệu của một dự án.
     * @param _projectId ID của dự án cần xác nhận.
     */
    function confirmData(uint256 _projectId) public onlyValidator {
        ProjectInfo storage project = projects[_projectId];
        require(bytes(project.name).length > 0, "Project does not exist.");
        // Chỉ có thể xác nhận khi dự án đang ở trạng thái Pending hoặc Challenged
        require(project.status == ProjectStatus.Pending || project.status == ProjectStatus.Challenged, "Project is not in pending or challenged state.");
        // Kiểm tra thời gian xác minh
        require(block.timestamp <= project.creationTime + VALIDATION_PERIOD_SECONDS, "Validation period for this project has expired.");
        require(!validatorConfirmed[_projectId][msg.sender], "You have already confirmed this project.");
        require(!validatorChallenged[_projectId][msg.sender], "You have challenged this project, cannot confirm."); // Một validator không thể vừa confirm vừa challenge

        validatorConfirmed[_projectId][msg.sender] = true;
        project.confirmCount += 1;
        emit ValidatorConfirmed(_projectId, msg.sender);

        // Nếu đủ số xác nhận và dự án đang Pending, chuyển trạng thái sang Validated
        if (project.confirmCount >= MIN_VALIDATORS_FOR_CONFIRM && project.status == ProjectStatus.Pending) {
            ProjectStatus oldStatus = project.status;
            project.status = ProjectStatus.Validated;
            emit ProjectStatusUpdated(_projectId, oldStatus, project.status, address(this));
        }
    }

    /**
     * @dev 3. Validator thách thức dữ liệu của một dự án (báo sai).
     * @param _projectId ID của dự án cần thách thức.
     */
    function challengeData(uint256 _projectId) public onlyValidator {
        ProjectInfo storage project = projects[_projectId];
        require(bytes(project.name).length > 0, "Project does not exist.");
        // Chỉ có thể thách thức khi dự án đang ở trạng thái Pending hoặc Validated
        require(project.status == ProjectStatus.Pending || project.status == ProjectStatus.Validated, "Project is not in pending or validated state.");
        // Kiểm tra thời gian thách thức
        require(block.timestamp <= project.creationTime + VALIDATION_PERIOD_SECONDS, "Challenge period for this project has expired.");
        require(!validatorChallenged[_projectId][msg.sender], "You have already challenged this project.");
        require(!validatorConfirmed[_projectId][msg.sender], "You have confirmed this project, cannot challenge."); // Một validator không thể vừa confirm vừa challenge

        validatorChallenged[_projectId][msg.sender] = true;
        project.challengeCount += 1;
        emit ValidatorChallenged(_projectId, msg.sender);

        // Ngay lập tức chuyển trạng thái sang Challenged khi có 1 challenge
        if (project.status != ProjectStatus.Challenged) { // Tránh emit event nếu đã Challenged
             ProjectStatus oldStatus = project.status;
             project.status = ProjectStatus.Challenged;
             emit ProjectStatusUpdated(_projectId, oldStatus, project.status, address(this));
        }
    }

    /**
     * @dev 4. Chủ sở hữu hợp đồng hoặc trọng tài giải quyết tranh chấp cho một dự án.
     * Chỉ có thể gọi khi dự án ở trạng thái Challenged.
     * @param _projectId ID của dự án.
     * @param _isValid True nếu tranh chấp được giải quyết và dự án được xác thực lại, False nếu dự án bị vô hiệu hóa.
     */
    function resolveDispute(uint256 _projectId, bool _isValid) public onlyOwner { // Có thể tạo vai trò Arbitrator riêng nếu phức tạp hơn
        ProjectInfo storage project = projects[_projectId];
        require(bytes(project.name).length > 0, "Project does not exist.");
        require(project.status == ProjectStatus.Challenged, "Project is not in a challenged state.");

        ProjectStatus oldStatus = project.status;
        if (_isValid) {
            project.status = ProjectStatus.Validated; // Quay lại trạng thái Validated
        } else {
            project.status = ProjectStatus.Invalidated; // Vô hiệu hóa dự án
            // Logic xử lý khi dự án bị Invalidated:
            // - Có thể cần hoàn trả phí đã nạp khi tạo dự án nếu muốn
            // - Đảm bảo không thể mint thêm tín chỉ
            // - Các tín chỉ đã mint có thể bị "flag" là từ dự án Invalidated (cần logic off-chain/frontend để hiển thị điều này)
        }
        emit ProjectStatusUpdated(_projectId, oldStatus, project.status, msg.sender);
    }

    /**
     * @dev 5. Mint (tạo ra) tín chỉ carbon cho một dự án đã được Validated.
     * Chỉ có Validator mới có thể gọi.
     * @param _to Địa chỉ nhận tín chỉ.
     * @param _projectId ID của dự án rừng (cũng là ID của loại token ERC1155).
     * @param _amount Số lượng tín chỉ carbon muốn mint (ví dụ: tính bằng tấn CO2).
     */
    function mintCarbonCredits(address _to, uint256 _projectId, uint256 _amount) public onlyValidator {
        ProjectInfo storage project = projects[_projectId];
        require(bytes(project.name).length > 0, "Project does not exist.");
        require(project.status == ProjectStatus.Validated, "Project not validated yet or is challenged/invalidated.");
        require(_amount > 0, "Amount to mint must be positive.");

        _mint(_to, _projectId, _amount, ""); // ERC1155 mints specific ID tokens
        project.totalMinted += _amount;
        emit CarbonCreditsMinted(_projectId, _to, _amount);
    }

    /**
     * @dev 6. Burn (thu hồi) tín chỉ carbon.
     * Người dùng tự đốt hoặc người được ủy quyền (approvedForAll) có thể đốt.
     * @param _from Địa chỉ sở hữu tín chỉ cần đốt.
     * @param _projectId ID của dự án (loại token ERC1155).
     * @param _amount Số lượng tín chỉ muốn đốt.
     */
    function burnCarbonCredits(address _from, uint256 _projectId, uint256 _amount) public {
        // Chỉ cho phép người sở hữu token hoặc người được approveForAll đốt
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "Caller is not owner nor approved.");
        require(bytes(projects[_projectId].name).length > 0, "Project does not exist.");
        require(_amount > 0, "Amount to burn must be positive.");

        // ERC1155 _burn đã tự động kiểm tra số dư.
        _burn(_from, _projectId, _amount);
        projects[_projectId].totalBurned += _amount;
        emit CarbonCreditsBurned(_projectId, _from, _amount);
    }

    /**
     * @dev 7. Chủ hệ thống thưởng validator bằng token ERC20.
     * Hợp đồng phải có đủ số lượng token thưởng.
     * @param _validator Địa chỉ của validator nhận thưởng.
     * @param _amount Số lượng token thưởng.
     */
    function rewardValidator(address _validator, uint256 _amount) public onlyOwner {
        require(validators[_validator], "Not a validator");
        require(_amount > 0, "Reward amount must be positive.");
        // Chuyển token thưởng từ hợp đồng đến validator
        require(rewardToken.transfer(_validator, _amount), "Reward token transfer failed. Check contract balance or allowance.");
        emit ValidationRewarded(_validator, _amount);
    }

    // --- Chức năng xem dữ liệu ---

    /**
     * @dev Lấy thông tin chi tiết của một dự án rừng.
     * @param _projectId ID của dự án.
     */
    function getProjectInfo(uint256 _projectId) public view returns (
        string memory name,
        string memory description,
        string memory location,
        string memory dataHash,
        address uploader,
        uint256 totalMinted,
        uint256 totalBurned,
        ProjectStatus status, // Trả về enum trạng thái
        uint256 confirmCount,
        uint256 challengeCount,
        uint256 creationTime
    ) {
        ProjectInfo storage proj = projects[_projectId];
        require(bytes(proj.name).length > 0, "Project not found.");
        return (
            proj.name,
            proj.description,
            proj.location,
            proj.dataHash,
            proj.uploader,
            proj.totalMinted,
            proj.totalBurned,
            proj.status,
            proj.confirmCount,
            proj.challengeCount,
            proj.creationTime
        );
    }

    /**
     * @dev Lấy số dư tín chỉ carbon của một người dùng cho một loại dự án cụ thể.
     * Sử dụng hàm balanceOf của ERC1155.
     * @param _projectId ID của dự án (loại token).
     * @param _user Địa chỉ người dùng.
     */
    function getUserCarbonCreditsBalance(uint256 _projectId, address _user) public view returns (uint256) {
        return balanceOf(_user, _projectId);
    }

    // Ghi đè hàm uri để có thể cung cấp URI metadata cho từng token ID
    // Trong thực tế, URI này sẽ trỏ đến một máy chủ JSON API
    // VD: "https://my-api.com/token/{id}"
    function uri(uint256 _tokenId) override public view returns (string memory) {
        // Kiểm tra xem projectId có tồn tại không
        // require(bytes(projects[_tokenId].name).length > 0, "Metadata for non-existent project ID."); // Có thể bỏ nếu URI server xử lý lỗi
        // Nối base URI (từ constructor) với Project ID
        return string(abi.encodePacked(super.uri(_tokenId), _tokenId.toString()));
    }
}
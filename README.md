# 🌳 Open Forest Protocol – Dự án Carbon Credit Blockchain

Dự án này phát triển nền tảng quản lý – giám sát – xác minh – báo cáo (MRV) tín chỉ carbon trên blockchain NEAR, với mục tiêu số hóa và minh bạch hóa tín chỉ carbon tự nhiên (nature-based credits), thúc đẩy các hoạt động trồng rừng, phục hồi rừng và hấp thụ CO₂ bền vững.

---

## 🎯 Mục tiêu dự án

Giải quyết các vấn đề nan giải của thị trường tín chỉ carbon truyền thống: thiếu minh bạch, chi phí MRV cao, greenwashing… bằng cách ứng dụng blockchain để:

📌 **Ghi nhận dữ liệu rừng bất biến**: Lưu trữ MRV on-chain, đảm bảo truy xuất nguồn gốc và chống gian lận.

📌 **Phát hành tín chỉ “ex-post”**: Chỉ tạo token carbon sau khi CO₂ thực sự được hấp thụ và xác minh.

📌 **Hạ chi phí MRV**: Sử dụng viễn thám, ảnh vệ tinh, LiDAR và AI để tự động hóa quy trình.

📌 **Hỗ trợ dự án nhỏ và cộng đồng địa phương**: Tăng khả năng tiếp cận thị trường tín chỉ carbon quốc tế.

---

## 🔗 Cấu hình hợp đồng thông minh

✅ **Token chuẩn ERC-1155** đại diện cho mỗi 1 tấn CO₂ đã được hấp thụ, chỉ phát hành sau xác minh dữ liệu rừng.

✅ **Hợp đồng quản lý**:
- Ghi dữ liệu MRV từ app thực địa và ảnh vệ tinh.
- Xác thực bởi validator mạng lưới – stake token để bỏ phiếu xác minh.
- Phát hành, giao dịch và đốt token carbon để bù đắp khí thải.

✅ **Tích hợp API**: Cho phép các nền tảng Web3, DeFi và DAO truy cập minh bạch.

---

## 🗂 Thư mục dự án

- `contracts/OpenForestToken.sol`: Hợp đồng quản lý phát hành tín chỉ carbon.
- `README.md`: Tổng quan dự án và hướng dẫn triển khai.
- `apps/ForesterApp`: Ứng dụng thu thập dữ liệu thực địa phục vụ MRV.

---

## 🛠 Công cụ sử dụng

- **Ngôn ngữ**: Solidity ^0.8.0
- **Blockchain**: NEAR Protocol (Aurora EVM)
- **IDE**: Remix / Hardhat
- **Ví**: MetaMask (Kết nối mạng NEAR Aurora hoặc testnet)

---

## 🔎 Hướng dẫn triển khai

1. Mở **Remix IDE** hoặc sử dụng **Hardhat**.  
2. Dán hợp đồng `OpenForestToken.sol` vào thư mục `contracts/`.  
3. Biên dịch và triển khai trên Aurora EVM (NEAR) hoặc testnet thông qua MetaMask.  
4. Sử dụng các hàm **registerForest**, **mintCredit**, **burnCredit** để tạo – quản lý – đốt tín chỉ carbon.  

---

## 🔍 Điểm nổi bật

✅ Minh bạch và bất biến nhờ blockchain – dữ liệu MRV có thể truy xuất công khai.  
✅ Cơ chế validator stake token để xác minh – đảm bảo phi tập trung và chống gian lận.  
✅ MRV tự động – giảm 70–80% chi phí so với phương pháp truyền thống.  
✅ Hệ sinh thái mở rộng – tích hợp API cho DeFi, DAO, và marketplace carbon.  

---

## ⚠️ Hạn chế và thử thách

- Chất lượng dữ liệu đầu vào phụ thuộc vào ảnh vệ tinh và thiết bị đo đạc thực địa.
- Chưa có tiêu chuẩn toàn cầu thống nhất cho token hóa tín chỉ carbon.
- Cần thời gian xây dựng mạng lưới validator và cộng đồng nhà phát triển mạnh mẽ.

---

## 🚀 Hướng phát triển

- Chuẩn hóa token OFP theo tiêu chuẩn quốc tế (Verra, Gold Standard).
- Mở rộng sang các loại hình như REDD+, rừng ngập mặn, nông lâm kết hợp (agroforestry).
- Phát triển giao diện người dùng đơn giản, dễ tiếp cận cho cộng đồng địa phương.
- Tích hợp sâu hơn với các nền tảng DeFi để nâng cao tính thanh khoản.

---

## 📄 Giấy phép

MIT License

---

## 🧪 Hướng dẫn kiểm thử trên Remix

1. Mở **Remix IDE**.  
2. Tạo tệp `OpenForestToken.sol` trong thư mục `contracts/` và dán mã nguồn vào.  
3. Chọn compiler Solidity (ví dụ: **0.8.20**).  
4. Chọn môi trường **Injected Web3** để kết nối MetaMask với mạng Aurora testnet.  
5. Triển khai hợp đồng và sử dụng các hàm chính bên dưới:  

---

## ⚙️ Ví dụ sử dụng các hàm chính

```solidity
createProject("Mangrove Forest", "ipfs://Qm...")
// Đăng ký dự án rừng với metadata gồm tên và IPFS chứa dữ liệu vệ tinh/LiDAR

confirmData(1)
// Validator xác nhận dữ liệu cho dự án có projectId = 1

challengeData(1)
// Validator thách thức dữ liệu nếu phát hiện sai lệch

mintCarbonCredits("0xAbc...123", 1, 50)
// Phát hành 50 token tín chỉ carbon cho địa chỉ ví từ dự án số 1

burnCarbonCredits("0xAbc...123", 1, 10)
// Đốt 10 token từ ví để ghi nhận hành động bù đắp CO₂

rewardValidator("0xValidator456...789", 100)
// Thưởng 100 token cho validator vì tham gia xác minh
---

## 📚 Một số thuật ngữ quan trọng

- **Token OFP**: Đại diện cho tín chỉ carbon, mỗi token = 1 tấn CO₂ đã hấp thụ.  
- **MRV (Monitoring, Reporting, Verification)**: Giám sát – Báo cáo – Xác minh.  
- **Validator**: Các node tham gia xác minh, stake token để bỏ phiếu.  
- **Ex-post Credit**: Tín chỉ carbon chỉ được phát hành sau khi quá trình hấp thụ CO₂ thực sự xảy ra và được xác minh.  
- **Greenwashing**: Hành vi gian lận môi trường – cố ý “tẩy xanh” nhằm đạt lợi ích tài chính.  
- **IPFS**: Hệ thống lưu trữ phi tập trung, bảo đảm dữ liệu MRV bất biến.  

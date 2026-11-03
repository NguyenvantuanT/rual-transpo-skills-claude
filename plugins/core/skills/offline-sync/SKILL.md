---
name: offline-sync
description: Đồng bộ offline và giải quyết xung đột — chốt chính sách trước, không xếp thứ tự bằng giờ thiết bị (HLC/vector clock), chiến lược theo từng field (LWW, counter, set), tombstone, outbox + cursor idempotent, test hội tụ. Dùng khi app cho sửa dữ liệu lúc mất mạng rồi đồng bộ lại.
---

# Offline sync & conflict resolution

Phỏng theo `offline-sync-and-conflict-resolution` của BOW Skills (MIT) — xem `THIRD_PARTY_NOTICES.md`. Luật số 1: **hội tụ là thứ phải thiết kế, không phải hy vọng.** Không giải thích được vì sao 2 bản sao có cùng tập thao tác ra cùng trạng thái → đó là bug mất dữ liệu chập chờn, không phải sync.

Cần thêm DB local (drift/isar/sqflite…) = thêm dependency → hỏi user. Chính sách chốt được ghi vào `docs/` của dự án.

## 1. Chốt yêu cầu trước khi chọn cơ chế

- Đơn vị xung đột: cả dòng, 1 field, hay vị trí trong list/text?
- Ghi đè im lặng có chấp nhận được không? (`lastViewedAt`: có; số tồn kho, ghi chú chung: không)
- Ai giải quyết: máy tự merge, theo policy, hay hỏi user? Không tự chế cách thứ tư giữa chừng.
- Offline tối đa bao lâu? (quyết định thời gian giữ tombstone)

"Lấy bản mới nhất" = last-writer-wins trá hình — mới nhất theo đồng hồ **của ai**?

## 2. Không xếp thứ tự bằng giờ thiết bị

Đồng hồ máy lệch, bị chỉnh tay → ghi "sớm hơn" mà thực ra xảy ra sau sẽ bị mất.
- LWW chỉ chấp nhận với tie-breaker toàn phần: so tuple `(hlc, deviceId)`, không so thời gian trần.
- Ưu tiên **Hybrid Logical Clock**: giờ vật lý nhưng không bao giờ lùi, luôn lớn hơn mọi stamp đã thấy.
- Cần biết nhân quả thật (A đã thấy B chưa?) → vector clock.

## 3. Chiến lược theo field, không theo cả app

| Field | Chiến lược |
|---|---|
| Scalar, mới nhất thắng | LWW register có HLC |
| Bộ đếm (like, delta tồn kho) | Gửi thao tác (+1/−1), cộng dồn — 2 lần +1 offline phải ra +2 |
| Tập hợp (tag, thành viên) | OR-Set — add + remove đồng thời không được mất add |
| Text tự do | OT / CRDT chuỗi — chỉ khi thật sự cần sửa đồng thời |
| Bất biến sau khi tạo | Từ chối khi xung đột, báo lên |

## 4. Xoá = tombstone, không phải biến mất

Dòng biến mất không phân biệt được với dòng chưa sync → sẽ "sống lại". Dùng `deleted_at` (có HLC), loại khỏi truy vấn đọc; quyết định trước: xoá thắng hay sửa làm sống lại. Chỉ dọn tombstone sau thời gian offline tối đa, không vì thiếu dung lượng.

## 5. Giao thức idempotent, tiếp tục được

- **Outbox** local: thao tác của user ghi vào outbox, đánh dấu đang gửi, chỉ xoá khi server ack.
- Mỗi thay đổi có **id do client tạo** → gửi lại không bị áp 2 lần.
- Pull theo **cursor đơn điệu** (seq server / HLC cao nhất), không theo offset trang. Áp thay đổi remote + lưu cursor mới **trong cùng 1 transaction local** — crash giữa chừng thì quay về trạng thái nhất quán.
- Supabase: bảng `change_log (seq identity, entity, entity_id, payload jsonb, hlc, deleted, actor)`, pull `where seq > :cursor order by seq limit :n`, **bắt buộc RLS** theo user/tenant (không thì change log là cửa sau tới mọi dòng — xem `supabase-security-review`).
- VM chỉ đọc trạng thái sync (đang sync / lỗi / số mục chờ) từ service; logic sync nằm trong service, không trong VM.

## 6. Test hội tụ như một tính chất

- Giao hoán: cùng tập thao tác, mọi thứ tự áp → cùng trạng thái (sinh ngẫu nhiên interleaving N thao tác × M bản sao, so bằng nhau).
- Idempotent: nhận lại thay đổi đã áp → không đổi gì.
- Replay 1 phiên offline đã ghi lại trong test CI.

## 7. Xung đột không tự giải được → nói thật

Giữ **cả 2 phiên bản** kèm stamp, có mặc định tất định + diff cho user khi cần người quyết. Log mọi lần tự giải kèm giá trị thua trong một khoảng thời gian để khôi phục. Không bao giờ "giải" bằng cách tải lại rồi đè lên dữ liệu local.

# tests/

TestEZ spec — ไฟล์ลงท้าย `.spec.luau`

ตัวที่ต้องมี test ก่อนเขียนโค้ด (RED ก่อน GREEN):
- Phase gate — boundary 9,999 / 10,000 / 10,001 และ 99,999 / 100,000
- VidQ tier — boundary accuracy 50/51, 100/101, 150/151, 200
- Mental zone — boundary 0 / 1 / 39 / 40 / 69 / 70 / 100
- Ending resolver — **priority order** คือจุดที่พังง่ายสุด เงื่อนไข overlap กัน
  ต้องมี case ที่ match หลาย ending พร้อมกัน แล้วยืนยันว่าได้ตัวที่ priority สูงกว่า
- Economy — เงินต่อคลิป + หักรายสัปดาห์ ตอนเงินไม่พอ

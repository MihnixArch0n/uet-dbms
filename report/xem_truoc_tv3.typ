// ============================================================
// BẢN XEM TRƯỚC CÁC PHẦN CỦA TV3 (không nộp file này)
// Biên dịch: typst compile report/xem_truoc_tv3.typ
// Định dạng trang giống bao_cao_tv1_nhap.typ; số mục có dấu chấm ở cuối (2.3.6.)
// ============================================================

#set page(
  paper: "a4",
  margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2cm),
  numbering: "1",
)
#set text(font: "New Computer Modern", size: 11pt, lang: "vi")
#set par(justify: true, leading: 0.85em)
#set heading(numbering: "1.1.")
#show heading.where(level: 2): it => {
  v(0.9em)
  it
  v(0.4em)
}
#show figure: set block(breakable: true)

// Đặt bộ đếm để mục này mang số 2, giống báo cáo chung
#counter(heading).update(1)
= Tìm hiểu và thực nghiệm về Durability \& Crash Recovery

== Đặt vấn đề
_(Phần của TV1, không có trong bản xem trước.)_

== Cơ chế của hai hệ
_(Phần flush log của TV1 và phần bảo vệ trang của TV2 đứng trước mục con dưới đây.)_

#include "tv3_2_2_checkpoint_phuc_hoi.typ"

#include "tv3_2_3_phuong_phap.typ"

== Kết quả thí nghiệm A
_(Phần của TV1.)_

== Kết quả thí nghiệm B
_(Phần của TV2.)_

#include "tv3_2_6_ket_qua_C.typ"

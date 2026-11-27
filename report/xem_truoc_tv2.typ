// ============================================================
// BẢN XEM TRƯỚC CÁC PHẦN CỦA TV2 (không nộp file này)
// Biên dịch: typst compile report/xem_truoc_tv2.typ
// Định dạng trang giống bao_cao_tv1_nhap.typ; số mục có dấu chấm ở cuối (2.2.x, 2.5.x)
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
_(Phần flush log của TV1 đứng trước mục con dưới đây.)_

#include "tv2_2_2_bao_ve_trang.typ"

_(Phần checkpoint và phục hồi của TV3 đứng sau mục con trên.)_

== Phương pháp thực nghiệm
_(Phần của TV3.)_

== Kết quả thí nghiệm A
_(Phần của TV1.)_

#include "tv2_2_5_ket_qua_B.typ"

== Kết quả thí nghiệm C
_(Phần của TV3.)_

// ============================================================
// Sơ đồ kiến trúc và khái niệm vẽ bằng Typst built-in
// Dùng cho report/bao_cao_tong_hop.typ
// ============================================================

#let _node(
  w,
  h,
  body,
  fill: rgb("#eaf1ff"),
  stroke: 1.1pt + rgb("#3b5bdb"),
  radius: 5pt,
  inset: 5pt,
) = box(
  width: w,
  height: h,
  fill: fill,
  stroke: stroke,
  radius: radius,
  inset: inset,
  align(center + horizon, body),
)

// Vẽ mũi tên thẳng từ (x1, y1) đến (x2, y2) với đầu tam giác
#let _arrow(x1, y1, x2, y2, stroke: 1.2pt + rgb("#343a40"), head: 5pt) = {
  let dx = (x2 - x1).pt()
  let dy = (y2 - y1).pt()
  let len = calc.sqrt(dx * dx + dy * dy)
  if len > 0 {
    let ux = dx / len
    let uy = dy / len
    // Điểm lùi lại để thân mũi tên không lòi qua đầu nhọn
    let bx = x2 - ux * head * 0.85
    let by = y2 - uy * head * 0.85
    let px = -uy * head * 0.48
    let py = ux * head * 0.48
    let col = stroke.paint
    place(top + left, line(start: (x1, y1), end: (bx, by), stroke: stroke))
    place(
      top + left,
      polygon(
        fill: col,
        stroke: none,
        (x2, y2),
        (bx + px, by + py),
        (bx - px, by - py),
      ),
    )
  }
}

// Vẽ mũi tên cong bậc hai từ (x1, y1) qua điểm điều khiển (cx, cy) tới (x2, y2)
#let _curved-arrow(x1, y1, cx, cy, x2, y2, stroke: 1.4pt + rgb("#2b8a3e"), head: 5.5pt) = {
  let tx = (x2 - cx).pt()
  let ty = (y2 - cy).pt()
  let len = calc.sqrt(tx * tx + ty * ty)
  let ux = tx / len
  let uy = ty / len
  let bx = x2 - ux * head * 0.85
  let by = y2 - uy * head * 0.85
  let px = -uy * head * 0.48
  let py = ux * head * 0.48
  let col = stroke.paint
  place(
    top + left,
    curve(
      stroke: stroke,
      curve.move((x1, y1)),
      curve.quad((cx, cy), (bx, by)),
    ),
  )
  place(
    top + left,
    polygon(
      fill: col,
      stroke: none,
      (x2, y2),
      (bx + px, by + py),
      (bx - px, by - py),
    ),
  )
}

// ============================================================
// H1 – Đường đi của dữ liệu từ DBMS đến đĩa và phạm vi mất dữ liệu
// ============================================================
#let diagram-data-path() = {
  // Tổng bề rộng 468pt (~16.5cm), vừa khít trang A4 của báo cáo
  let W = 468pt
  let H = 236pt

  let c0 = 0pt
  let cw0 = 90pt
  let bw = 70pt
  let gap = 30pt

  let x1 = 94pt
  let x2 = x1 + bw + gap
  let x3 = x2 + bw + gap
  let x4 = x3 + bw + gap

  let y-boxes = 62pt
  let bh = 44pt

  let red-fill-1 = rgb("#ffa8a8")
  let red-fill-2 = rgb("#ff8787")
  let red-fill-3 = rgb("#fa5252")
  let red-stroke = 1pt + rgb("#c92a2a")

  box(width: W, height: H, {
    set text(size: 8.2pt)
    set par(justify: false, leading: 0.45em)

    // Tiêu đề
    place(
      top + left,
      dx: 0pt,
      dy: 0pt,
      box(width: W, align(center, text(size: 9.8pt, weight: "bold")[
        Dữ liệu COMMIT chỉ an toàn khi đã tới tầng ④
      ])),
    )

    // Nhãn & mũi tên cong fsync()
    place(
      top + left,
      dx: x2 - 12pt,
      dy: 16pt,
      box(
        width: x4 + bw - x2 + 12pt,
        align(center, text(size: 7.7pt, weight: "bold", fill: rgb("#2b8a3e"))[
          `fsync()` / `fdatasync()` đẩy dữ liệu xuống tầng ④ rồi mới báo xong
        ]),
      ),
    )
    _curved-arrow(
      x2 + bw / 2,
      y-boxes - 3pt,
      (x2 + x4 + bw) / 2,
      26pt,
      x4 + bw / 2,
      y-boxes - 3pt,
      stroke: 1.4pt + rgb("#2b8a3e"),
    )

    // 4 hộp tầng lưu trữ
    place(top + left, dx: x1, dy: y-boxes, _node(
      bw,
      bh,
      text(size: 7.4pt)[*① Bộ đệm DBMS*\ (shared buffers,\ WAL / log buffer)],
      fill: rgb("#e7f0ff"),
      stroke: 1.1pt + rgb("#3b5bdb"),
    ))
    place(top + left, dx: x2, dy: y-boxes, _node(
      bw,
      bh,
      text(size: 7.4pt)[*② Page cache*\ của hệ điều hành],
      fill: rgb("#e7f0ff"),
      stroke: 1.1pt + rgb("#3b5bdb"),
    ))
    place(top + left, dx: x3, dy: y-boxes, _node(
      bw,
      bh,
      text(size: 7.4pt)[*③ Cache của*\ ổ đĩa],
      fill: rgb("#e7f0ff"),
      stroke: 1.1pt + rgb("#3b5bdb"),
    ))
    place(top + left, dx: x4, dy: y-boxes, _node(
      bw,
      bh,
      text(size: 7.4pt)[*④ Bề mặt lưu trữ*\ (flash / đĩa từ)],
      fill: rgb("#d3f9d8"),
      stroke: 1.2pt + rgb("#2b8a3e"),
    ))

    // Mũi tên ngang giữa 4 tầng
    let ym = y-boxes + bh / 2
    _arrow(x1 + bw + 2pt, ym, x2 - 2pt, ym)
    place(top + left, dx: x1 + bw - 2pt, dy: ym - 12pt, box(width: gap + 4pt, align(center, text(size: 6.8pt, fill: rgb("#495057"))[`write()`])))

    _arrow(x2 + bw + 2pt, ym, x3 - 2pt, ym)
    place(top + left, dx: x2 + bw - 2pt, dy: ym - 12pt, box(width: gap + 4pt, align(center, text(size: 6.8pt, fill: rgb("#495057"))[ghi ổ])))

    _arrow(x3 + bw + 2pt, ym, x4 - 2pt, ym)
    place(top + left, dx: x3 + bw - 2pt, dy: ym - 12pt, box(width: gap + 4pt, align(center, text(size: 6.8pt, fill: rgb("#495057"))[xả cache])))

    // Phần dưới: ma trận phạm vi mất dữ liệu
    let y-sub = 120pt
    place(
      top + left,
      dx: 0pt,
      dy: y-sub,
      text(size: 8.6pt, weight: "bold")[Dữ liệu bị mất theo loại sự cố (các tầng tô đỏ bị xóa):],
    )

    let row-h = 19pt
    let row-gap = 7pt
    let yr1 = y-sub + 17pt
    let yr2 = yr1 + row-h + row-gap
    let yr3 = yr2 + row-h + row-gap

    // Hàng 1: Crash tiến trình DBMS
    place(top + left, dx: c0, dy: yr1, box(width: cw0, height: row-h, align(left + horizon, text(size: 7.6pt)[
      Crash tiến trình DBMS\ #text(size: 7pt, fill: rgb("#495057"))[(kill -9, OOM)]
    ])))
    place(top + left, dx: x1, dy: yr1, rect(width: bw, height: row-h, fill: red-fill-1, stroke: red-stroke, radius: 4pt))
    place(top + left, dx: x1 + bw + 6pt, dy: yr1, box(height: row-h, align(left + horizon, text(size: 7.8pt, weight: "bold", fill: rgb("#c92a2a"))[mất ①])))

    // Hàng 2: Crash hệ điều hành
    place(top + left, dx: c0, dy: yr2, box(width: cw0, height: row-h, align(left + horizon, text(size: 7.6pt)[
      Crash hệ điều hành\ #text(size: 7pt, fill: rgb("#495057"))[(kernel panic, tắt VM)]
    ])))
    place(top + left, dx: x1, dy: yr2, rect(width: bw, height: row-h, fill: red-fill-2, stroke: red-stroke, radius: 4pt))
    place(top + left, dx: x2, dy: yr2, rect(width: bw, height: row-h, fill: red-fill-2, stroke: red-stroke, radius: 4pt))
    place(top + left, dx: x2 + bw + 6pt, dy: yr2, box(height: row-h, align(left + horizon, text(size: 7.8pt, weight: "bold", fill: rgb("#c92a2a"))[mất ① ②])))

    // Hàng 3: Mất điện
    place(top + left, dx: c0, dy: yr3, box(width: cw0, height: row-h, align(left + horizon, text(size: 7.6pt)[
      Mất điện #text(size: 7pt, fill: rgb("#495057"))[(nếu ổ không\ tôn trọng lệnh flush)]
    ])))
    place(top + left, dx: x1, dy: yr3, rect(width: bw, height: row-h, fill: red-fill-3, stroke: red-stroke, radius: 4pt))
    place(top + left, dx: x2, dy: yr3, rect(width: bw, height: row-h, fill: red-fill-3, stroke: red-stroke, radius: 4pt))
    place(top + left, dx: x3, dy: yr3, rect(width: bw, height: row-h, fill: red-fill-3, stroke: red-stroke, radius: 4pt))
    place(top + left, dx: x3 + bw + 6pt, dy: yr3, box(height: row-h, align(left + horizon, text(size: 7.8pt, weight: "bold", fill: rgb("#c92a2a"))[mất ① ② ③])))

    // Chú thích cuối
    place(
      top + left,
      dx: 0pt,
      dy: yr3 + row-h + 10pt,
      text(size: 7.4pt, fill: rgb("#495057"))[
        Dữ liệu đã tới tầng ④ (sau `fsync`) thì còn nguyên sau mọi loại sự cố trên (giả sử ổ tôn trọng lệnh flush).
      ],
    )
  })
}

// ============================================================
// H2 – Kiến trúc tiến trình và bộ nhớ của PostgreSQL
// ============================================================
#let diagram-pg-arch() = {
  let W = 468pt
  let H = 266pt

  box(width: W, height: H, {
    set text(size: 8.2pt)
    set par(justify: false, leading: 0.45em)

    // Tiêu đề
    place(
      top + left,
      dx: 0pt,
      dy: 0pt,
      box(width: W, align(center, text(size: 9.8pt, weight: "bold")[
        Kiến trúc tiến trình và bộ nhớ của PostgreSQL
      ])),
    )

    // --- Tầng trên: Client -> postmaster -> backend 1..N ---
    let y-top = 20pt
    let x-cli = 12pt
    let w-cli = 84pt
    let h-cli = 36pt
    let y-cli = y-top + 22pt

    place(top + left, dx: x-cli, dy: y-cli, _node(
      w-cli,
      h-cli,
      text(size: 7.8pt)[*Client*\ (psql, ứng dụng)],
      fill: rgb("#f1f3f5"),
      stroke: 1.1pt + rgb("#495057"),
    ))

    let x-pm = 124pt
    let w-pm = 94pt
    let h-pm = 38pt
    let y-pm = y-top + 21pt

    place(top + left, dx: x-pm, dy: y-pm, _node(
      w-pm,
      h-pm,
      text(size: 7.8pt)[*postmaster*\ (lắng nghe, fork)],
      fill: rgb("#fff3bf"),
      stroke: 1.2pt + rgb("#e67700"),
    ))

    _arrow(x-cli + w-cli + 2pt, y-cli + h-cli / 2, x-pm - 2pt, y-pm + h-pm / 2)
    place(top + left, dx: x-cli + w-cli + 2pt, dy: y-cli + h-cli / 2 - 12pt, box(width: x-pm - x-cli - w-cli - 4pt, align(center, text(size: 7.2pt)[kết nối])))

    // 3 backend boxes
    let x-be = 252pt
    let w-be = 96pt
    let h-be = 22pt
    let be-gap = 5pt
    let y-be1 = y-top
    let y-be2 = y-be1 + h-be + be-gap
    let y-be3 = y-be2 + h-be + be-gap

    place(top + left, dx: x-be, dy: y-be1, _node(w-be, h-be, text(size: 7.8pt)[backend 1], fill: rgb("#e7f0ff"), stroke: 1pt + rgb("#3b5bdb"), radius: 4pt))
    place(top + left, dx: x-be, dy: y-be2, _node(w-be, h-be, text(size: 7.8pt)[backend 2], fill: rgb("#e7f0ff"), stroke: 1pt + rgb("#3b5bdb"), radius: 4pt))
    place(top + left, dx: x-be, dy: y-be3, _node(w-be, h-be, text(size: 7.8pt)[backend N], fill: rgb("#e7f0ff"), stroke: 1pt + rgb("#3b5bdb"), radius: 4pt))

    // Mũi tên fork từ postmaster tới 3 backend
    let pm-rx = x-pm + w-pm + 2pt
    let pm-cy = y-pm + h-pm / 2
    _arrow(pm-rx, pm-cy - 6pt, x-be - 2pt, y-be1 + h-be / 2)
    _arrow(pm-rx, pm-cy, x-be - 2pt, y-be2 + h-be / 2)
    _arrow(pm-rx, pm-cy + 6pt, x-be - 2pt, y-be3 + h-be / 2)
    place(top + left, dx: x-pm + w-pm + 4pt, dy: y-be1 + 2pt, text(size: 7.2pt)[fork])

    // Chú thích process-per-connection
    place(
      top + left,
      dx: x-be + w-be + 10pt,
      dy: y-be1 + 10pt,
      box(width: 98pt, text(size: 7.5pt, fill: rgb("#495057"))[
        mỗi kết nối một tiến trình\ (process-per-connection)
      ]),
    )

    // --- Tầng giữa: Bộ nhớ chung & Tiến trình nền ---
    let y-mid = 116pt
    let h-mid = 66pt

    // Khung Bộ nhớ chung (trái)
    let x-shm = 12pt
    let w-shm = 248pt
    place(
      top + left,
      dx: x-shm,
      dy: y-mid,
      rect(width: w-shm, height: h-mid, fill: rgb("#f3f0ff"), stroke: 1.2pt + rgb("#7048e8"), radius: 6pt),
    )
    place(
      top + left,
      dx: x-shm + 8pt,
      dy: y-mid + 5pt,
      text(size: 8pt, weight: "bold", fill: rgb("#5f3dc4"))[Bộ nhớ chung (shared memory)],
    )
    place(top + left, dx: x-shm + 8pt, dy: y-mid + 20pt, _node(
      112pt,
      38pt,
      text(size: 7.5pt)[*shared buffers*\ (cache trang 8 KB)],
      fill: rgb("#e5dbff"),
      stroke: 1pt + rgb("#7048e8"),
      radius: 4pt,
    ))
    place(top + left, dx: x-shm + 128pt, dy: y-mid + 20pt, _node(
      112pt,
      38pt,
      text(size: 7.5pt)[*WAL buffers*\ (bản ghi WAL chưa ghi)],
      fill: rgb("#e5dbff"),
      stroke: 1pt + rgb("#7048e8"),
      radius: 4pt,
    ))

    // Khung Tiến trình nền (phải)
    let x-bg = 272pt
    let w-bg = 184pt
    place(
      top + left,
      dx: x-bg,
      dy: y-mid,
      rect(width: w-bg, height: h-mid, fill: rgb("#fff9db"), stroke: 1.2pt + rgb("#e67700"), radius: 6pt),
    )
    place(
      top + left,
      dx: x-bg + 8pt,
      dy: y-mid + 5pt,
      text(size: 8pt, weight: "bold", fill: rgb("#d9480f"))[Tiến trình nền],
    )
    let bg-bw = 82pt
    let bg-bh = 17pt
    place(top + left, dx: x-bg + 8pt, dy: y-mid + 20pt, _node(bg-bw, bg-bh, text(size: 7.3pt)[checkpointer], fill: rgb("#ffec99"), stroke: 0.9pt + rgb("#e67700"), radius: 3pt, inset: 2pt))
    place(top + left, dx: x-bg + 94pt, dy: y-mid + 20pt, _node(bg-bw, bg-bh, text(size: 7.3pt)[background writer], fill: rgb("#ffec99"), stroke: 0.9pt + rgb("#e67700"), radius: 3pt, inset: 2pt))
    place(top + left, dx: x-bg + 8pt, dy: y-mid + 41pt, _node(bg-bw, bg-bh, text(size: 7.3pt)[WAL writer], fill: rgb("#ffec99"), stroke: 0.9pt + rgb("#e67700"), radius: 3pt, inset: 2pt))
    place(top + left, dx: x-bg + 94pt, dy: y-mid + 41pt, _node(bg-bw, bg-bh, text(size: 7.3pt)[autovacuum], fill: rgb("#ffec99"), stroke: 0.9pt + rgb("#e67700"), radius: 3pt, inset: 2pt))

    // Mũi tên từ backend N xuống Bộ nhớ chung
    let purple-stroke = 1.2pt + rgb("#5f3dc4")
    _arrow(x-be + 10pt, y-be3 + h-be + 1pt, x-shm + 135pt, y-mid - 2pt, stroke: purple-stroke)
    _arrow(x-be + 36pt, y-be3 + h-be + 1pt, x-shm + 215pt, y-mid - 2pt, stroke: purple-stroke)
    place(top + left, dx: x-shm + 148pt, dy: y-be3 + h-be + 3pt, text(size: 7.3pt, fill: rgb("#5f3dc4"))[đọc/ghi trang])

    // --- Tầng dưới: Đĩa ($PGDATA) ---
    let y-disk = 208pt
    let h-disk = 56pt
    let x-disk = 12pt
    let w-disk = 444pt

    place(
      top + left,
      dx: x-disk,
      dy: y-disk,
      rect(width: w-disk, height: h-disk, fill: rgb("#e6fcf5"), stroke: 1.2pt + rgb("#0ca678"), radius: 6pt),
    )
    place(
      top + left,
      dx: x-disk + 8pt,
      dy: y-disk + 5pt,
      text(size: 8pt, weight: "bold", fill: rgb("#087f5b"))[Đĩa (`$PGDATA`)],
    )

    let dw = 136pt
    let dh = 30pt
    let dy-in = y-disk + 19pt
    place(top + left, dx: x-disk + 8pt, dy: dy-in, _node(dw, dh, text(size: 7.3pt)[*`base/`* – file dữ liệu\ (heap, chỉ mục, TOAST)], fill: rgb("#c3fae8"), stroke: 0.9pt + rgb("#0ca678"), radius: 4pt, inset: 3pt))
    place(top + left, dx: x-disk + 154pt, dy: dy-in, _node(dw, dh, text(size: 7.3pt)[*`pg_wal/`* – file WAL 16 MB], fill: rgb("#c3fae8"), stroke: 0.9pt + rgb("#0ca678"), radius: 4pt, inset: 3pt))
    place(top + left, dx: x-disk + 300pt, dy: dy-in, _node(dw, dh, text(size: 7.3pt)[*`global/pg_control`* –\ vị trí checkpoint cuối], fill: rgb("#c3fae8"), stroke: 0.9pt + rgb("#0ca678"), radius: 4pt, inset: 3pt))

    // Mũi tên xuống Đĩa
    let green-stroke = 1.2pt + rgb("#087f5b")
    _arrow(x-shm + 64pt, y-mid + 59pt, x-disk + 78pt, y-disk - 2pt, stroke: green-stroke)
    place(top + left, dx: x-shm + 26pt, dy: y-mid + 69pt, text(size: 7.3pt, fill: rgb("#087f5b"))[ghi trang])

    _arrow(x-shm + 190pt, y-mid + 59pt, x-disk + 220pt, y-disk - 2pt, stroke: green-stroke)
    place(top + left, dx: x-shm + 214pt, dy: y-mid + 67pt, text(size: 7.2pt, fill: rgb("#087f5b"))[flush WAL\ khi COMMIT])

    _arrow(x-bg + 48pt, y-mid + h-mid + 1pt, x-disk + 258pt, y-disk - 2pt, stroke: 1.2pt + rgb("#d9480f"))
  })
}

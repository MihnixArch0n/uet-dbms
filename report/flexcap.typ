// Chú thích ngắn cho Danh mục các bảng / các hình: trong danh mục chỉ hiện câu đầu của chú thích.
#let in-outline = state("in-outline", false)
#let fcap(short, long) = context if in-outline.get() { short } else { long }

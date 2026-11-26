| db | level | value | số lần crash | tổng giao dịch mất | mất nhiều nhất / lần | RPO lớn nhất (ms) | bất biến sai (lần) | giao dịch lạ | RTO trung bình (s) | redo trung bình (s) |
|---|---|---|---|---|---|---|---|---|---|---|
| mysql | os | 0 | 5 | 8071 | 3517 | 629.6 | 0 | 0 | 20.0 | 2.466 |
| mysql | os | 1 | 3 | 0 | 0 | 0.0 | 0 | 0 | 23.58 | 1.413 |
| mysql | os | 2 | 5 | 4926 | 2674 | 551.7 | 0 | 0 | 27.03 | 2.413 |
| mysql | process | 0 | 5 | 118 | 108 | 18.6 | 0 | 0 | 23.86 | 9.291 |
| mysql | process | 1 | 3 | 0 | 0 | 0.0 | 0 | 0 | 20.24 | 8.568 |
| mysql | process | 2 | 5 | 0 | 0 | 0.0 | 0 | 0 | 23.1 | 9.23 |
| pg | os | off | 5 | 2687 | 897 | 196.6 | 0 | 0 | 22.59 | 3.822 |
| pg | os | on | 3 | 0 | 0 | 0.0 | 0 | 0 | 20.54 | 1.743 |
| pg | process | off | 5 | 80 | 69 | 20.1 | 0 | 0 | 11.64 | 1.198 |
| pg | process | on | 3 | 0 | 0 | 0.0 | 0 | 0 | 9.87 | 0.59 |

# Expansion Bus Net Names

## 8-bit Section — B1–B31 / A1–A31

| Pin | A-side (right) | B-side (left) |
|----:|:---------------|:--------------|
|  1  | BA1            |               |
|  2  | D7             | /CPU_RST      |
|  3  | D6             |               |
|  4  | D5             | BB4           |
|  5  | D4             |               |
|  6  | D3             |               |
|  7  | D2             |               |
|  8  | D1             |               |
|  9  | D0             |               |
| 10  | /CPU_WAIT      |               |
| 11  | /CPU_M1        | /B8_MEM_WR    |
| 12  | MA19           | /B8_MEM_RD    |
| 13  | MA18           | /BIO_WR       |
| 14  | MA17           | /BIO_RD       |
| 15  | MA16           | /BIACK        |
| 16  | MA15           | BINTEN        |
| 17  | MA14           | /CPU_BUSACK   |
| 18  | MA13           | /CPU_BUSRQ    |
| 19  | A12            | /CPU_RFSH     |
| 20  | A11            | BCLK          |
| 21  | A10            | BIRQ7         |
| 22  | A9             | BIRQ6         |
| 23  | A8             | BIRQ5         |
| 24  | A7             | BIRQ4         |
| 25  | A6             | BIRQ3         |
| 26  | A5             | BIRQ2         |
| 27  | A4             | BIRQ1         |
| 28  | A3             | BIRQ0         |
| 29  | A2             |               |
| 30  | A1             | CLK20         |
| 31  | A0             |               |

## 16-bit Extension — C1–C18 / D1–D18

| Pin | C-side (right) | D-side (left) |
|----:|:---------------|:--------------|
|  1  | BC1            | /CPU_MREQ     |
|  2  | BC2            | /CPU_IORQ     |
|  3  | MA25           | A13           |
|  4  | MA24           | A14           |
|  5  | MA23           | A15           |
|  6  | MA22           | BINTACK0      |
|  7  | MA21           | BINTACK1      |
|  8  | MA20           | BINTACK2      |
|  9  | /CPU_RD        | BINTACK3      |
| 10  | /CPU_WR        | BINTACK4      |
| 11  | BC11           | BINTACK5      |
| 12  | BC12           | BINTACK6      |
| 13  | BC13           | BINTACK7      |
| 14  | BC14           |               |
| 15  | BC15           |               |
| 16  | BC16           |               |
| 17  | BC17           |               |
| 18  | BC18           |               |

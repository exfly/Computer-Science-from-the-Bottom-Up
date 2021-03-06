# 十六进制

十六进制指的是一个基数为16的计数系统。我们在计算机科学中使用它只有一个原因，它能帮助人类更容易地理解二进制数。计算机只和二进制打交道，而十六进制是人类尝试与计算机共事的捷径。

所以为什么以16为基数？好吧，最自然的选择是以10为基数，因为我们习惯了在日常计数系统使用10进制思考。但是基数10在二进制上不怎么好使——要用二进制表示10个不同的元素，我们需要四个二进制位。四个二进制位，可以给我们16种可能组合。所以我们可以采用非常困难的方法在10进制与2进制之间转换，或者采用一种简单的方法——构建一个基数为16的计数系统——十六进制。

十六进制标准的10进制数字，但是加入了ABCDEF代表10 11 12 13 14 15（注意。我们从零开始。）

传统上，每一次你看到一个带有***0x***前缀的数这表示一个十六进制数。

前面提到了，要在二进制中表示16种不同形式，我们需要恰好四个二进制位。所以，每个十六进制数表示着恰好四个比特。你应该把背出下面这张表当作是练习。

### 表2.11 十六进制，二进制和十进制

| Hexadecimal | Binary | Decimal |
| ----------- | ------ | ------- |
| `0`         | `0000` | `0`     |
| `1`         | `0001` | `1`     |
| `2`         | `0010` | `2`     |
| `3`         | `0011` | `3`     |
| `4`         | `0100` | `4`     |
| `5`         | `0101` | `5`     |
| `6`         | `0110` | `6`     |
| `7`         | `0111` | `7`     |
| `8`         | `1000` | `8`     |
| `9`         | `1001` | `9`     |
| `A`         | `1010` | `10`    |
| `B`         | `1011` | `11`    |
| `C`         | `1100` | `12`    |
| `D`         | `1101` | `13`    |
| `E`         | `1110` | `14`    |
| `F`         | `1111` | `15`    |

当然没有理由不将这种模式继续下去，（比如说，把G分配给16），但是16个值是人类记忆的变幻莫测和计算机使用的位数之间的一个很好的折衷（你也许偶尔会看到8进制的使用，比如说UNIX下文件的权限）。我们简单地将大量的二进制位使用更多的数字表示。例如，一个16个二进制位的变量可以被表示成0xAB12，要将它转换为二进制，取出每一位数，按照上面的表来转换然后把它们组成在一起（所以0xAB12最终成了16位二进制数1010101100010010）。我们可以逆向把二进制转换成十六进制。

我们也可以使用重复除法的方式来改变一个数字的基数。例如，求出203对应的十六进制数。

### 表2.12 将203转换成十六进制数

| Quotient            |      | Remainder |      |
| ------------------- | ---- | --------- | ---- |
| $$203_{10}$$ ÷ 16 = | 12   | 11 (0xB)  |      |
| $$12_{10}$$ ÷ 16 =  | 0    | 12 (0xC)  | ↑    |

因此十六进制中203表示为0xCB。
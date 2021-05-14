#!/usr/bin/env python3
import re

txt = "ta I tell youa what a a"
mat3 = re.findall("\w*a", txt)
print(mat3)

mat = re.search("\w*a", txt)
mat2 = re.split("\w*a", txt)
print(mat)
print(mat.span())
print(mat.string)
print(mat.group())
print(mat2)

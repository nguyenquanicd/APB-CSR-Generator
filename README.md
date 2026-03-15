# CSR Generation Tool
This tool is used to generate CSR module based on the configuration in workbook file

## 🚀 Features
- CSR module:
- Support Read Write (rw), Read Only (ro), Read Write and Insert (rwi), Write 1 to clear (w1c)
- Asynchronous option, can set register clock and bus clock asynchronous each together

## 🛠 Installation
- Python
- getpass
- datetime
- os
## ▶️ Run program
- Configure workbook file
- run command: {your python env} CSR_Generation {workbook file} {sheet_name}
    example: python3.9 CSR_Generation workbook.xlsx CSR
- Check the output at RTL, Debug
- Remember to replace the synchronizer module at RTL/models
#--------------------------------------------------------------------
# Build the test workbook for the HW-priority tests.
# Usage: python3.9 -s make_workbook.py <out.xlsx>
# Sheets: SYNC_PRIO (Asynchronous=0) and ASYNC_PRIO (Asynchronous=1),
# same register map, so the same testbench runs on both.
#--------------------------------------------------------------------
import sys
import openpyxl

REGS = [
    # name, offset, [(bit name, field, type)]
    ("sts", "0x0000", [
        ("reserved", "[31:8]", "ro"),
        ("cnt",      "[7:4]",  "rwi"),   # multi-bit rwi
        ("evt2",     "[3]",    "w1c"),
        ("mode",     "[2]",    "rw"),
        ("evt",      "[1]",    "w1c"),
        ("go",       "[0]",    "rwi"),
    ]),
    ("aux", "0x0004", [
        ("val",      "[31:0]", "rw"),
    ]),
]

def build_sheet(wb, title, module, async_opt):
    ws = wb.create_sheet(title)
    ws.append(["Table - Configuration"])
    ws.append(["Config", "Value", "Description"])
    ws.append(["Module Name", module])
    ws.append(["Protocol", "APB"])
    ws.append(["Data Width", 32])
    ws.append(["Address Width", 16])
    ws.append(["Write Strobe", 4])
    ws.append(["Asynchronous", async_opt])
    ws.append(["Table - Register Definition"])
    ws.append(["REGISTER", "OFFSET", "BIT NAME", "FIELD WIDTH", "BIT TYPE", "RESET VALUE", "DESCRIPTION"])
    for name, off, bits in REGS:
        ws.append([name, off, None, None, None, "0x0", None])
        for bname, field, btype in bits:
            ws.append([None, None, bname, field, btype, "0x0", "test field"])

wb = openpyxl.Workbook()
wb.remove(wb.active)
build_sheet(wb, "SYNC_PRIO",  "m_csr_prio_sync",  0)
build_sheet(wb, "ASYNC_PRIO", "m_csr_prio_async", 1)
wb.save(sys.argv[1])

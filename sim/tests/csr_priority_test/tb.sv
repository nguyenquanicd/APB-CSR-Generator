`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Testbench: HW-vs-SW priority on rwi / w1c fields
// Rule under test: when HW and SW update the same field in the same register
// clock cycle, HW wins. A SW write to a register must never discard a HW event
// on a different field of that register, and must not be lost on other fields.
//
// Build flags (see run.sh):
//   -DDUT_NAME=<module>   module generated from make_workbook.py
//   -DASYNC               DUT has a separate i_reg_clk / i_reg_rstn domain
//
// Register map (sts @0x0): [0] go rwi, [1] evt w1c, [2] mode rw, [3] evt2 w1c,
//                          [7:4] cnt rwi, [31:8] reserved
//                (aux @0x4): [31:0] val rw
//
// Collisions are made cycle-exact by watching dut.we_sts (the register write
// enable) at the middle of a HW-clock cycle and driving i_hw_we_* so that it is
// sampled on the same edge as the SW commit.
//------------------------------------------------------------------------------
module tb_csr;

  localparam [15:0] PARA_STS = 16'h0000;
  localparam [15:0] PARA_AUX = 16'h0004;

  // Bit positions in sts
  localparam [31:0] M_GO   = 32'h0000_0001;
  localparam [31:0] M_EVT  = 32'h0000_0002;
  localparam [31:0] M_MODE = 32'h0000_0004;
  localparam [31:0] M_EVT2 = 32'h0000_0008;

  reg          i_bus_clk;
  reg          i_bus_rstn;
  reg  [15:0]  i_paddr;
  reg          i_protect_en;
  reg          i_slverr_en;
  reg  [2:0]   i_pprot;
  reg  [31:0]  i_pwdata;
  reg          i_pwrite;
  reg          i_penable;
  reg          i_psel;
  reg  [3:0]   i_pstrb;
  wire         o_pslverr;
  wire         o_pready;
  wire [31:0]  o_prdata;

  wire [3:0]   o_sts_cnt;
  reg  [3:0]   i_hw_wdata_sts_cnt;
  reg          i_hw_we_sts_cnt;
  wire         o_sts_evt2;
  reg          i_hw_wdata_sts_evt2;
  reg          i_hw_we_sts_evt2;
  wire         o_sts_mode;
  wire         o_sts_evt;
  reg          i_hw_wdata_sts_evt;
  reg          i_hw_we_sts_evt;
  wire         o_sts_go;
  reg          i_hw_wdata_sts_go;
  reg          i_hw_we_sts_go;
  wire [31:0]  o_aux_val;

`ifdef ASYNC
  reg          i_reg_clk;
  reg          i_reg_rstn;
  initial i_reg_clk = 1'b0;
  always #7 i_reg_clk = ~i_reg_clk;          // 14 ns: not a multiple of the bus clock
  wire hw_clk = i_reg_clk;
`else
  wire hw_clk = i_bus_clk;
`endif

  initial i_bus_clk = 1'b0;
  always #5 i_bus_clk = ~i_bus_clk;          // 10 ns

  `DUT_NAME dut (.*);

  integer tests_passed = 0;
  integer tests_failed = 0;

  `define CHECK_EQ(actual, expected, msg) \
    if ((actual) !== (expected)) begin \
      $display("[%0t] FAIL: %s (expected=0x%0h, actual=0x%0h)", $time, msg, expected, actual); \
      tests_failed = tests_failed + 1; \
    end else begin \
      $display("[%0t] PASS: %s", $time, msg); \
      tests_passed = tests_passed + 1; \
    end

  //----------------------------------------------------------------------------
  // Basic tasks
  //----------------------------------------------------------------------------
  task wait_bus_posedge;
    @(posedge i_bus_clk);
  endtask

  task hw_idle;
    i_hw_we_sts_cnt = 1'b0;  i_hw_wdata_sts_cnt  = 4'h0;
    i_hw_we_sts_evt2 = 1'b0; i_hw_wdata_sts_evt2 = 1'b0;
    i_hw_we_sts_evt = 1'b0;  i_hw_wdata_sts_evt  = 1'b0;
    i_hw_we_sts_go = 1'b0;   i_hw_wdata_sts_go   = 1'b0;
  endtask

  task sys_reset;
    hw_idle;
    i_bus_rstn = 1'b0;
`ifdef ASYNC
    i_reg_rstn = 1'b0;
`endif
    repeat (4) wait_bus_posedge;
    @(negedge i_bus_clk);
    i_bus_rstn = 1'b1;
`ifdef ASYNC
    @(negedge i_reg_clk);
    i_reg_rstn = 1'b1;
`endif
    repeat (4) wait_bus_posedge;
  endtask

  task apb_write(input [15:0] addr, input [31:0] wdata);
    integer guard;
    begin
      @(negedge i_bus_clk);
      i_psel    = 1'b1;
      i_penable = 1'b0;
      i_pwrite  = 1'b1;
      i_paddr   = addr;
      i_pwdata  = wdata;
      i_pstrb   = 4'b1111;
      wait_bus_posedge;
      @(negedge i_bus_clk);
      i_penable = 1'b1;
      wait_bus_posedge;
      guard = 0;
      while (!o_pready && guard < 200) begin wait_bus_posedge; guard = guard + 1; end
      if (guard >= 200) begin
        $display("[%0t] FAIL: apb_write timeout", $time);
        tests_failed = tests_failed + 1;
      end
      @(negedge i_bus_clk);
      i_psel    = 1'b0;
      i_penable = 1'b0;
    end
  endtask

  task apb_read(input [15:0] addr, output [31:0] rdata);
    integer guard;
    begin
      @(negedge i_bus_clk);
      i_psel    = 1'b1;
      i_penable = 1'b0;
      i_pwrite  = 1'b0;
      i_paddr   = addr;
      i_pstrb   = 4'b1111;
      wait_bus_posedge;
      @(negedge i_bus_clk);
      i_penable = 1'b1;
      wait_bus_posedge;
      guard = 0;
      while (!o_pready && guard < 200) begin wait_bus_posedge; guard = guard + 1; end
      if (guard >= 200) begin
        $display("[%0t] FAIL: apb_read timeout", $time);
        tests_failed = tests_failed + 1;
      end
      rdata = o_prdata;
      @(negedge i_bus_clk);
      i_psel    = 1'b0;
      i_penable = 1'b0;
    end
  endtask

  // One HW event: drive the staged values for exactly one HW-clock edge.
  task hw_pulse(input we_cnt,  input [3:0] d_cnt,
                input we_evt2, input d_evt2,
                input we_evt,  input d_evt,
                input we_go,   input d_go);
    begin
      @(negedge hw_clk);
      i_hw_we_sts_cnt  = we_cnt;  i_hw_wdata_sts_cnt  = d_cnt;
      i_hw_we_sts_evt2 = we_evt2; i_hw_wdata_sts_evt2 = d_evt2;
      i_hw_we_sts_evt  = we_evt;  i_hw_wdata_sts_evt  = d_evt;
      i_hw_we_sts_go   = we_go;   i_hw_wdata_sts_go   = d_go;
      @(negedge hw_clk);
      hw_idle;
    end
  endtask

  // SW write to `addr` with a HW event aligned `offset` HW-clock cycles after
  // the cycle in which the register write enable (dut.we_sts) is active.
  // offset = 0 is the same-edge collision.
  task sw_write_collide(input [15:0] addr, input [31:0] wdata, input integer offset,
                        input we_cnt,  input [3:0] d_cnt,
                        input we_evt2, input d_evt2,
                        input we_evt,  input d_evt,
                        input we_go,   input d_go);
    reg seen;
    integer t;
    begin
      seen = 1'b0;
      fork
        apb_write(addr, wdata);
        begin : inj
          t = 0;
          @(negedge hw_clk);
          while (dut.we_sts !== 1'b1 && t < 300) begin
            @(negedge hw_clk);
            t = t + 1;
          end
          if (dut.we_sts === 1'b1) begin
            seen = 1'b1;
            repeat (offset) @(negedge hw_clk);
            i_hw_we_sts_cnt  = we_cnt;  i_hw_wdata_sts_cnt  = d_cnt;
            i_hw_we_sts_evt2 = we_evt2; i_hw_wdata_sts_evt2 = d_evt2;
            i_hw_we_sts_evt  = we_evt;  i_hw_wdata_sts_evt  = d_evt;
            i_hw_we_sts_go   = we_go;   i_hw_wdata_sts_go   = d_go;
            @(negedge hw_clk);
            hw_idle;
          end
        end
      join
      if (!seen) begin
        $display("[%0t] FAIL: write-enable pulse (dut.we_sts) never observed", $time);
        tests_failed = tests_failed + 1;
      end
    end
  endtask

  // Read sts back and compare against the expected low byte; also compare the
  // register outputs and check the reserved bits read as zero.
  task check_sts(input [7:0] exp, input string name);
    reg [31:0] rd;
    begin
      repeat (6) @(negedge hw_clk);
      apb_read(PARA_STS, rd);
      `CHECK_EQ(rd[7:0], exp, {name, " : sts readback"})
      `CHECK_EQ({o_sts_cnt, o_sts_evt2, o_sts_mode, o_sts_evt, o_sts_go}, exp, {name, " : outputs"})
      `CHECK_EQ(rd[31:8], 24'h0, {name, " : reserved reads 0"})
    end
  endtask

  //----------------------------------------------------------------------------
  // Tests
  //----------------------------------------------------------------------------
  initial begin
    reg [31:0] rd;

    $display("========================================");
    $display("CSR priority test: DUT=%0s", `"`DUT_NAME`");
    $display("========================================");

    i_protect_en = 1'b0;
    i_slverr_en  = 1'b0;
    i_pprot      = 3'b000;
    i_psel       = 1'b0;
    i_penable    = 1'b0;
    i_pwrite     = 1'b0;
    i_paddr      = 16'h0;
    i_pwdata     = 32'h0;
    i_pstrb      = 4'hF;
    hw_idle;
    sys_reset;

    // ---- Regression: behaviour without collision -------------------------------
    $display("--- T01 w1c: HW set alone");
    sys_reset;
    hw_pulse(0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    check_sts(8'h02, "T01");

    $display("--- T02 w1c: SW write 1 clears");
    sys_reset;
    hw_pulse(0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    apb_write(PARA_STS, M_EVT);
    check_sts(8'h00, "T02");

    $display("--- T03 w1c: SW write 0 is a no-op");
    sys_reset;
    hw_pulse(0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    apb_write(PARA_STS, 32'h0);
    check_sts(8'h02, "T03");

    $display("--- T04 rwi/rw: SW write, no collision");
    sys_reset;
    apb_write(PARA_STS, 32'h0000_00A5);       // cnt=A mode=1 go=1
    check_sts(8'hA5, "T04");

    $display("--- T05 rwi: HW write alone (handshake ack clears go)");
    sys_reset;
    apb_write(PARA_STS, M_GO);
    hw_pulse(0,4'h0, 0,1'b0, 0,1'b0, 1,1'b0);
    check_sts(8'h00, "T05");

    // ---- BUG A: HW event on a w1c lost when SW writes another field -----------
    $display("--- T06 [BUG-A] SW sets go while HW sets evt, same cycle");
    sys_reset;
    sw_write_collide(PARA_STS, M_GO, 0,  0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    check_sts(8'h03, "T06 go=1 evt=1");

    $display("--- T07 [BUG-A] SW sets mode while HW sets evt, same cycle");
    sys_reset;
    sw_write_collide(PARA_STS, M_MODE, 0,  0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    check_sts(8'h06, "T07 mode=1 evt=1");

    $display("--- T08 [BUG-A] SW writes 0 to a w1c (no-op) while HW sets it, same cycle");
    sys_reset;
    sw_write_collide(PARA_STS, 32'h0, 0,  0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    check_sts(8'h02, "T08 evt=1");

    // ---- BUG B: SW clear vs HW set on the same w1c bit ------------------------
    $display("--- T09 [BUG-B] SW clears evt while HW sets evt, same cycle -> HW wins");
    sys_reset;
    hw_pulse(0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);          // evt pending
    sw_write_collide(PARA_STS, M_EVT, 0,  0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    check_sts(8'h02, "T09 evt stays 1");

    // ---- BUG C: rwi, SW vs HW on the same field --------------------------------
    $display("--- T10 [BUG-C] go pending, SW writes 1 while HW acks (clears) -> HW wins");
    sys_reset;
    apb_write(PARA_STS, M_GO);
    sw_write_collide(PARA_STS, M_GO, 0,  0,4'h0, 0,1'b0, 0,1'b0, 1,1'b0);
    check_sts(8'h00, "T10 go=0");

    $display("--- T11 [BUG-C] SW writes 0 to go while HW sets it -> HW wins");
    sys_reset;
    sw_write_collide(PARA_STS, 32'h0, 0,  0,4'h0, 0,1'b0, 0,1'b0, 1,1'b1);
    check_sts(8'h01, "T11 go=1");

    $display("--- T12 [BUG-C] multi-bit rwi cnt: HW value wins, mode from SW still lands");
    sys_reset;
    sw_write_collide(PARA_STS, 32'h0000_00A4, 0,  1,4'h5, 0,1'b0, 0,1'b0, 0,1'b0);
    check_sts(8'h54, "T12 cnt=5 mode=1");

    // ---- Guards: the fix must not block unrelated SW writes --------------------
    $display("--- T13 [GUARD] SW clears evt2 while HW sets evt (different w1c fields)");
    sys_reset;
    hw_pulse(0,4'h0, 1,1'b1, 0,1'b0, 0,1'b0);          // evt2 pending
    sw_write_collide(PARA_STS, M_EVT2, 0,  0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    check_sts(8'h02, "T13 evt2 cleared by SW, evt set by HW");

    $display("--- T14 [GUARD] SW writes go+mode while HW writes cnt (different rwi fields)");
    sys_reset;
    sw_write_collide(PARA_STS, 32'h0000_0005, 0,  1,4'h9, 0,1'b0, 0,1'b0, 0,1'b0);
    check_sts(8'h95, "T14 cnt=9 (HW) go=1 mode=1 (SW)");

    $display("--- T15 [GUARD] SW write to aux while HW sets evt in sts (other register)");
    sys_reset;
    fork
      apb_write(PARA_AUX, 32'hCAFE_F00D);
      begin
        repeat (2) @(negedge hw_clk);
        hw_pulse(0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
      end
    join
    check_sts(8'h02, "T15 evt=1");
    `CHECK_EQ(o_aux_val, 32'hCAFE_F00D, "T15 aux written")

    // ---- Sequential ordering (HW event one cycle after the SW commit) ----------
    $display("--- T16 HW sets evt one cycle after SW clear commit -> evt=1");
    sys_reset;
    hw_pulse(0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    sw_write_collide(PARA_STS, M_EVT, 1,  0,4'h0, 0,1'b0, 1,1'b1, 0,1'b0);
    check_sts(8'h02, "T16");

    $display("--- T17 HW acks go one cycle after SW write commit -> go=0");
    sys_reset;
    sw_write_collide(PARA_STS, M_GO, 1,  0,4'h0, 0,1'b0, 0,1'b0, 1,1'b0);
    check_sts(8'h00, "T17");

    // ---- Handshake: go -> HW sees o_sts_go -> HW acks --------------------------
    $display("--- T18 handshake: SW sets go, HW model acks when it sees o_sts_go");
    sys_reset;
    apb_write(PARA_STS, M_GO);
    begin : hs
      integer t;
      t = 0;
      @(negedge hw_clk);
      while (o_sts_go !== 1'b1 && t < 100) begin @(negedge hw_clk); t = t + 1; end
      `CHECK_EQ(o_sts_go, 1'b1, "T18 go visible to HW")
      hw_pulse(0,4'h0, 0,1'b0, 0,1'b0, 1,1'b0);
    end
    check_sts(8'h00, "T18 go cleared by ack");

    $display("========================================");
    $display("RESULT: %0d passed, %0d failed", tests_passed, tests_failed);
    $display("========================================");
    if (tests_failed != 0) $fatal(1, "CSR priority test FAILED");
    $finish;
  end

  initial begin
    #5_000_000;
    $display("TIMEOUT");
    $fatal(1, "CSR priority test timeout");
  end

endmodule

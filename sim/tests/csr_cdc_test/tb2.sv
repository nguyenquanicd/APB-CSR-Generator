`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Testbench: m_vlsi_csr CDC edge-case testbench
// Description: Same test sequence as csr_test/tb2.sv, but with i_clk_reg
// deliberately much FASTER than i_clk_apb (3ns vs 10ns), so that a single
// i_clk_reg-domain enable pulse is narrower than one i_clk_apb period. This
// is the specific ratio needed to expose the o_apb_prdata cross-domain bug
// fixed in CSR_Generation.py (apb_read_en, generated in the i_clk_reg
// domain, used to directly gate an i_clk_apb-domain capture FF): with
// csr_test/tb2.sv's 10ns/15ns ratio, the reg_clk pulse is always wider
// than one bus_clk period and the miss can never be observed in
// zero-delay simulation, so that config alone is not a discriminating
// regression test for this bug. Run with:
//   TEST=csr_cdc_test make -f Makefile_async run
//------------------------------------------------------------------------------
module tb_csr;

  // Parameters
  localparam [15:0] PARA_ABC_OFFSET = 16'h0;
  localparam [15:0] PARA_DEF_OFFSET = 16'h4;
  localparam integer PARA_CLK_PERIOD = 10;
  localparam integer PARA_CLK_REG_PERIOD = 3;

  // Testbench signals
  reg          i_clk_apb;
  reg          i_rst_n_apb;
  reg          i_clk_reg;
  reg          i_rst_n_reg;
  reg  [15:0]  i_apb_paddr;
  reg          i_protect_en;
  reg          i_slverr_en;
  reg  [2:0]   i_apb_pprot;
  reg  [31:0]  i_apb_pwdata;
  reg          i_apb_pwrite;
  reg          i_apb_penable;
  reg          i_apb_psel;
  reg  [3:0]   i_apb_pstrb;
  wire         o_apb_pslverr;
  wire         o_apb_pready;
  wire [31:0]  o_apb_prdata;
  reg          i_abc_start0;
  wire         o_abc_start1;
  wire         o_abc_start2;
  reg          i_hw_wdata_abc_start2;
  reg          i_hw_we_abc_start2;
  wire [1:0]   o_abc_start3;
  wire [1:0]   o_abc_start4;
  reg  [1:0]   i_hw_wdata_abc_start4;
  reg          i_hw_we_abc_start4;
  wire         o_def_start0;
  wire         o_def_start1;
  reg          i_hw_wdata_def_start1;
  reg          i_hw_we_def_start1;
  reg [1:0]         i_hw_wdata_def_start3;
  reg          i_hw_we_def_start3;
  wire         o_def_start2;
  wire [1:0]        o_def_start3;
  reg          i_hw_wdata_def_start2;
  reg          i_hw_we_def_start2;
  reg  [1:0]   i_def_start3;
  wire [1:0]   o_def_start4;
  reg  [1:0]   i_hw_wdata_def_start4;
  reg          i_hw_we_def_start4;

  // Test counters
  integer tests_passed = 0;
  integer tests_failed = 0;

  // DUT instantiation
  m_vlsi_csr dut (.*);

  // Clock generation
  initial i_clk_apb = 1'b0;
  always #(PARA_CLK_PERIOD/2) i_clk_apb = ~i_clk_apb;
  initial i_clk_reg = 1'b0;
  always #(PARA_CLK_REG_PERIOD/2) i_clk_reg = ~i_clk_reg;

  // Helper tasks
  task wait_posedge;
    @(posedge i_clk_apb);
  endtask

  task sys_reset;
    i_rst_n_apb = 1'b0;
    repeat(3) wait_posedge;
    @(negedge i_clk_apb);
    i_rst_n_apb = 1'b1;
  endtask
  task sys2_reset;
    i_rst_n_reg = 1'b0;
    repeat(3) wait_posedge;
    @(negedge i_clk_reg);
    i_rst_n_reg = 1'b1;
  endtask

  task apb_write(input [15:0] addr, input [31:0] wdata);
    @(negedge i_clk_apb);
    i_apb_psel    = 1'b1;
    i_apb_penable = 1'b0;
    i_apb_pwrite  = 1'b1;
    i_apb_paddr   = addr;
    i_apb_pwdata  = wdata;
    i_apb_pstrb   = 4'b1111;
    wait_posedge;
    @(negedge i_clk_apb);
    i_apb_penable = 1'b1;
    wait_posedge;
    while (!o_apb_pready) wait_posedge;
    @(negedge i_clk_apb);
    i_apb_psel    = 1'b0;
    i_apb_penable = 1'b0;
  endtask

  task apb_read(input [15:0] addr, output [31:0] rdata);
    @(negedge i_clk_apb);
    i_apb_psel    = 1'b1;
    i_apb_penable = 1'b0;
    i_apb_pwrite  = 1'b0;
    i_apb_paddr   = addr;
    i_apb_pstrb   = 4'b1111;
    wait_posedge;
    @(negedge i_clk_apb);
    i_apb_penable = 1'b1;
    wait_posedge;
    while (!o_apb_pready) wait_posedge;
    rdata = o_apb_prdata;
    @(negedge i_clk_apb);
    i_apb_psel    = 1'b0;
    i_apb_penable = 1'b0;
  endtask

  // Assertion macros
  `define ASSERT(cond, msg) \
    if (!(cond)) begin \
      $display("[%0t] FAIL: %s", $time, msg); \
      tests_failed = tests_failed + 1; \
    end else begin \
      $display("[%0t] PASS: %s", $time, msg); \
      tests_passed = tests_passed + 1; \
    end

  `define ASSERT_EQ(actual, expected, msg) \
    if ((actual) !== (expected)) begin \
      $display("[%0t] FAIL: %s (expected=0x%0h, actual=0x%0h)", $time, msg, expected, actual); \
      tests_failed = tests_failed + 1; \
    end else begin \
      $display("[%0t] PASS: %s", $time, msg); \
      tests_passed = tests_passed + 1; \
    end

  // Test sequence
  initial begin
    integer i;
    logic [31:0] rdata;
    logic [31:0] cdc_wpat;
    logic [31:0] cdc_expected;

    $display("========================================");
    $display("m_vlsi_csr CSR Module Test");
    $display("========================================");

    // Initialize inputs
    i_protect_en           = 1'b0;
    i_slverr_en            = 1'b1;
    i_apb_pprot                = 3'b000;
    i_apb_psel                 = 1'b0;
    i_apb_penable              = 1'b0;
    i_apb_pwrite               = 1'b0;
    i_apb_paddr                = 16'h0;
    i_apb_pwdata               = 32'h0;
    i_apb_pstrb                = 4'b1111;
    i_abc_start0           = 1'b0;
    i_hw_wdata_abc_start2  = 1'b0;
    i_hw_we_abc_start2     = 1'b0;
    i_hw_wdata_abc_start4  = 2'b00;
    i_hw_we_abc_start4     = 1'b0;
    i_hw_wdata_def_start1  = 1'b0;
    i_hw_we_def_start1     = 1'b0;
    i_hw_wdata_def_start2  = 1'b0;
    i_hw_we_def_start2     = 1'b0;
    i_hw_wdata_def_start3  = 2'b0;
    i_hw_we_def_start3     = 1'b0;
    i_def_start3           = 2'b00;
    i_hw_wdata_def_start4  = 2'b00;
    i_hw_we_def_start4     = 1'b0;

    sys_reset();
    sys2_reset();
    #10;

    // Test 1: Reset and Write to ABC register
    $display("\n--- Test 1: Write to ABC register ---");
    `ASSERT_EQ(o_abc_start1, 1'b0, "abc_start1 should be 0 after reset");
    `ASSERT_EQ(o_abc_start2, 1'b0, "abc_start2 should be 0 after reset)");
    `ASSERT_EQ(o_abc_start3, 2'b00, "abc_start3 should be 0 after reseti");
    `ASSERT_EQ(o_abc_start4, 2'b00, "abc_start4 should be 0 after reset");
    apb_write(PARA_ABC_OFFSET, 32'hffff_ffff);
    #PARA_CLK_REG_PERIOD
    `ASSERT_EQ(o_abc_start1, 1'b1, "abc_start1 should be 1 after write");
    `ASSERT_EQ(o_abc_start2, 1'b1, "abc_start2 should be 1 after write");
    `ASSERT_EQ(o_abc_start3, 2'b11, "abc_start3 should be 2'b11 after write");
    `ASSERT_EQ(o_abc_start4, 2'b11, "abc_start4 should be 2'b11 after write");

    // Test 2: Read back ABC register
    $display("\n--- Test 2: Read back ABC register ---");
    apb_read(PARA_ABC_OFFSET, rdata);
    #PARA_CLK_REG_PERIOD
    `ASSERT_EQ(rdata[31], 1'b0, "rdata[31] Read back abc_start0 should be 0");
    `ASSERT_EQ(rdata[30], 1'b1, "rdata[30] Read back abc_start1 should be 1");
    `ASSERT_EQ(rdata[29], 1'b1, "rdata[29] Read back abc_start2 should be 1");
    `ASSERT_EQ(rdata[28:27], 2'b11, "rdata[28:27] Read back abc_start3 should be 2'b11");
    `ASSERT_EQ(rdata[26:25], 2'b11, "rdata[26:25] Read back abc_start4 should be 2'b11");
    `ASSERT_EQ(rdata[24:0], 25'h0, "rdata[24:0] Read back reserved should be 25'h0");

    // Test 3: HW write to abc register
    $display("\n--- Test 5: HW write to abc_start2 ---");
    i_hw_wdata_abc_start2 = 1'b0;
    i_hw_we_abc_start2    = 1'b1;
    i_hw_wdata_abc_start4 = 2'b10;
    i_hw_we_abc_start4    = 1'b1;
    #PARA_CLK_REG_PERIOD;
    `ASSERT_EQ(o_abc_start2, 1'b0, "abc_start2 should be 0 after HW write");
    i_hw_we_abc_start2    = 1'b0;
    i_hw_we_abc_start4    = 1'b0;
    $display("\n--- Test 3: Read back ABC register ---");
    apb_read(PARA_ABC_OFFSET, rdata);
    #PARA_CLK_REG_PERIOD
    `ASSERT_EQ(rdata[31], 1'b0, "rdata[31] Read back abc_start0 should be 0");
    `ASSERT_EQ(rdata[30], 1'b1, "rdata[30] Read back abc_start1 should be 1");
    `ASSERT_EQ(rdata[29], 1'b0, "rdata[29] Read back abc_start2 should be 1");
    `ASSERT_EQ(rdata[28:27], 2'b11, "rdata[28:27] Read back abc_start3 should be 2'b11");
    `ASSERT_EQ(rdata[26:25], 2'b10, "rdata[26:25] Read back abc_start4 should be 2'b10");
    `ASSERT_EQ(rdata[24:0], 25'h0, "rdata[24:0] Read back reserved should be 25'h0");
    
    // Test 4: Write to DEF register
    $display("\n--- Test 4: Write to DEF register ---");
    apb_write(PARA_DEF_OFFSET, 32'h8000_0000);
    `ASSERT_EQ(o_def_start0, 1'b1, "def_start0 should be 1 after write");
    `ASSERT_EQ(o_def_start1, 1'b0, "def_start1 should be 0 (HW not driving)");
    `ASSERT_EQ(o_def_start2, 1'b0, "def_start2 should be 0 (HW not driving)");
    `ASSERT_EQ(o_def_start4, 2'b00, "def_start4 should be 00 after write");

    // Test 5: Read back DEF register
    $display("\n--- Test 5: Read back DEF register ---");
    apb_read(PARA_DEF_OFFSET, rdata);
    `ASSERT_EQ(rdata[31], 1'b1, "Read back def_start0 should be 1");

    // Test 8: HW write to def_start1
    $display("\n--- Test 8: HW write to def_start1 ---");
    i_hw_wdata_def_start1 = 1'b1;
    i_hw_we_def_start1    = 1'b1;
    #PARA_CLK_REG_PERIOD;
    `ASSERT_EQ(o_def_start1, 1'b1, "def_start1 should be 1 after HW write");
    i_hw_we_def_start1    = 1'b0;

    // Test 9: Address error (misaligned address)
    $display("\n--- Test 9: Address error test ---");
    @(negedge i_clk_apb);
    i_apb_psel    = 1'b1;
    i_apb_penable = 1'b0;
    i_apb_pwrite  = 1'b1;
    i_apb_paddr   = 16'h1;  // Misaligned
    i_apb_pstrb   = 4'b1111;
    wait_posedge;
    @(negedge i_clk_apb);
    i_apb_penable = 1'b1;
    wait_posedge;
    while (!o_apb_pready) wait_posedge;
    `ASSERT_EQ(o_apb_pslverr, 1'b1, "pslverr should be 1 for misaligned address");
    i_apb_psel = 1'b0;

    // Test 10: Protection error
    $display("\n--- Test 10: Protection error test ---");
    i_protect_en = 1'b1;
    i_apb_pprot      = 3'b010;  // Non-secure access
    apb_write(PARA_ABC_OFFSET, 32'h0);
    `ASSERT_EQ(o_apb_pslverr, 1'b1, "pslverr should be 1 for protection violation");
    i_protect_en = 1'b0;
    i_apb_pprot      = 3'b000;


    // Test 11: HWI test - APB write-0 should NOT clear HW-set bit
    $display("\n--- Test 11: HWI test - APB write-0 to clear ---");
    // HW writes 1 to def_start1
    i_hw_wdata_def_start1 = 1'b1;
    i_hw_we_def_start1    = 1'b1;
    wait_posedge;
    i_hw_we_def_start1    = 1'b0;
    `ASSERT_EQ(o_def_start1, 1'b1, "def_start1 should be 1 after HW write");
    
    // Clear by APB writing 0
    apb_write(PARA_DEF_OFFSET, 32'h0000_0000);  // Write 0 to all bits
    `ASSERT_EQ(o_def_start1, 1'b0, "def_start1 should be 0 after APB write-0 (HWI behavior)");
    

    apb_write(16'h8, 32'h0000_0000);  // Write 0 to all bits
    // Test 12: W1C test - Multiple HW-set bits cleared selectively
    $display("\n--- Test 12: W1C test - Multiple bits selective clear ---");
    // HW sets both abc_start2 and abc_start4
    i_hw_wdata_def_start2 = 1'b1;
    i_hw_we_def_start2    = 1'b1;
    i_hw_wdata_def_start3 = 2'b11;
    i_hw_we_def_start3    = 1'b1;
    #PARA_CLK_REG_PERIOD
    i_hw_we_def_start2    = 1'b0;
    i_hw_we_def_start3    = 1'b0;
    `ASSERT_EQ(o_def_start2, 1'b1, "def_start2 should be 1 after HW write");
    `ASSERT_EQ(o_def_start3, 2'b11, "def_start3 should be 11 after HW write");
    
    // APB writes 1 only to clear abc_start2, not abc_start4
    apb_write(PARA_DEF_OFFSET, 32'h28000000);  // Write 1 to bit[29] only
    `ASSERT_EQ(o_def_start2, 1'b0, "def_start2 should be 0 after clearing by APB");
    `ASSERT_EQ(o_def_start3, 2'b10, "only def_start3[0] is cleared");

    // Test 13: CDC data-integrity stress test.
    // Regression for the o_apb_prdata async resync fix: reg_prdata now latches
    // in the i_clk_reg domain (qualified by apb_read_en, same domain) and
    // is resynced into i_clk_apb via reg_prdata_bus, gated by the already
    // bus-clock-synchronized read_aclk_bus_clk_falling pulse. Before the
    // fix, apb_read_en (an i_clk_reg-domain pulse) directly gated an
    // i_clk_apb-domain FF, so a fast, back-to-back write/read burst across
    // the deliberately non-integer-ratio i_clk_apb/i_clk_reg periods
    // (10ns/15ns) could catch o_apb_prdata holding stale data even while
    // o_apb_pready correctly reported completion. This loop alternates full
    // 0/1 write patterns with no extra settle time between transactions to
    // maximize handshake toggle rate and catch any such miss.
    $display("\n--- Test 13: CDC data-integrity stress (back-to-back reads) ---");
    i_hw_we_abc_start2 = 1'b0;
    i_hw_we_abc_start4 = 1'b0;
    for (i = 0; i < 20; i = i + 1) begin
      cdc_wpat = i[0] ? 32'hFFFF_FFFF : 32'h0000_0000;
      apb_write(PARA_ABC_OFFSET, cdc_wpat);
      apb_read(PARA_ABC_OFFSET, rdata);
      cdc_expected = {1'b0, cdc_wpat[30:25], 25'h0}; // bit31=i_abc_start0(0), bits24:0=reserved(0)
      `ASSERT_EQ(rdata, cdc_expected, $sformatf("CDC stress iter %0d: prdata must reflect last write as soon as pready asserts", i));
    end

    // Summary
    #20;
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Tests Passed: %0d", tests_passed);
    $display("Tests Failed: %0d", tests_failed);
    if (tests_failed == 0)
      $display("ALL TESTS PASSED!");
    else
      $display("SOME TESTS FAILED!");
    $display("========================================");

    $finish;
  end

  // Waveform dumping
  initial begin
`ifdef VERILATOR
    $dumpfile("tb_csr.vcd");
    $dumpvars(0, tb_csr);
`else
    $fsdbDumpfile("tb_csr.fsdb");
    $fsdbDumpvars(0, tb_csr, "+all");
`endif
  end

endmodule

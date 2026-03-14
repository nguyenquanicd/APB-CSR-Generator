`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Testbench: m_vlsi_csr testbench
// Description: Tests the CSR module with APB interface
//------------------------------------------------------------------------------
module tb_csr;

  // Parameters
  localparam [15:0] PARA_ABC_OFFSET = 16'h0;
  localparam [15:0] PARA_DEF_OFFSET = 16'h4;
  localparam integer PARA_CLK_PERIOD = 10;

  // Testbench signals
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
  initial i_bus_clk = 1'b0;
  always #(PARA_CLK_PERIOD/2) i_bus_clk = ~i_bus_clk;

  // Helper tasks
  task wait_posedge;
    @(posedge i_bus_clk);
  endtask

  task sys_reset;
    i_bus_rstn = 1'b0;
    repeat(3) wait_posedge;
    @(negedge i_bus_clk);
    i_bus_rstn = 1'b1;
  endtask

  task apb_write(input [15:0] addr, input [31:0] wdata);
    @(negedge i_bus_clk);
    i_psel    = 1'b1;
    i_penable = 1'b0;
    i_pwrite  = 1'b1;
    i_paddr   = addr;
    i_pwdata  = wdata;
    i_pstrb   = 4'b1111;
    wait_posedge;
    @(negedge i_bus_clk);
    i_penable = 1'b1;
    wait_posedge;
    while (!o_pready) wait_posedge;
    @(negedge i_bus_clk);
    i_psel    = 1'b0;
    i_penable = 1'b0;
  endtask

  task apb_read(input [15:0] addr, output [31:0] rdata);
    @(negedge i_bus_clk);
    i_psel    = 1'b1;
    i_penable = 1'b0;
    i_pwrite  = 1'b0;
    i_paddr   = addr;
    i_pstrb   = 4'b1111;
    wait_posedge;
    @(negedge i_bus_clk);
    i_penable = 1'b1;
    wait_posedge;
    while (!o_pready) wait_posedge;
    rdata = o_prdata;
    @(negedge i_bus_clk);
    i_psel    = 1'b0;
    i_penable = 1'b0;
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

    $display("========================================");
    $display("m_vlsi_csr CSR Module Test");
    $display("========================================");

    // Initialize inputs
    i_protect_en           = 1'b0;
    i_slverr_en            = 1'b1;
    i_pprot                = 3'b000;
    i_psel                 = 1'b0;
    i_penable              = 1'b0;
    i_pwrite               = 1'b0;
    i_paddr                = 16'h0;
    i_pwdata               = 32'h0;
    i_pstrb                = 4'b1111;
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
    #10;

    // Test 1: Write to ABC register
    $display("\n--- Test 1: Write to ABC register ---");
    apb_write(PARA_ABC_OFFSET, 32'h6000_0000);
    `ASSERT_EQ(o_abc_start1, 1'b1, "abc_start1 should be 1 after write");
    `ASSERT_EQ(o_abc_start2, 1'b0, "abc_start2 should be 0 (HW not driving)");
    `ASSERT_EQ(o_abc_start3, 2'b00, "abc_start3 should be 00 after write");
    `ASSERT_EQ(o_abc_start4, 2'b00, "abc_start4 should be 00 after write");

    // Test 2: Read back ABC register
    $display("\n--- Test 2: Read back ABC register ---");
    apb_read(PARA_ABC_OFFSET, rdata);
    `ASSERT_EQ(rdata[30], 1'b1, "Read back abc_start1 should be 1");

    // Test 3: Write to DEF register
    $display("\n--- Test 3: Write to DEF register ---");
    apb_write(PARA_DEF_OFFSET, 32'h8000_0000);
    `ASSERT_EQ(o_def_start0, 1'b1, "def_start0 should be 1 after write");
    `ASSERT_EQ(o_def_start1, 1'b0, "def_start1 should be 0 (HW not driving)");
    `ASSERT_EQ(o_def_start2, 1'b0, "def_start2 should be 0 (HW not driving)");
    `ASSERT_EQ(o_def_start4, 2'b00, "def_start4 should be 00 after write");

    // Test 4: Read back DEF register
    $display("\n--- Test 4: Read back DEF register ---");
    apb_read(PARA_DEF_OFFSET, rdata);
    `ASSERT_EQ(rdata[31], 1'b1, "Read back def_start0 should be 1");

    // Test 5: HW write to abc_start2
    $display("\n--- Test 5: HW write to abc_start2 ---");
    i_hw_wdata_abc_start2 = 1'b1;
    i_hw_we_abc_start2    = 1'b1;
    wait_posedge;
    `ASSERT_EQ(o_abc_start2, 1'b1, "abc_start2 should be 1 after HW write");
    i_hw_we_abc_start2    = 1'b0;

    // Test 6: HW write to abc_start4
    $display("\n--- Test 6: HW write to abc_start4 ---");
    i_hw_wdata_abc_start4 = 2'b11;
    i_hw_we_abc_start4    = 1'b1;
    wait_posedge;
    `ASSERT_EQ(o_abc_start4, 2'b11, "abc_start4 should be 11 after HW write");
    i_hw_we_abc_start4    = 1'b0;

    // Test 7: HW write to def_start1
    $display("\n--- Test 7: HW write to def_start1 ---");
    i_hw_wdata_def_start1 = 1'b1;
    i_hw_we_def_start1    = 1'b1;
    wait_posedge;
    `ASSERT_EQ(o_def_start1, 1'b1, "def_start1 should be 1 after HW write");
    i_hw_we_def_start1    = 1'b0;

    // Test 8: Read-only input def_start3
    $display("\n--- Test 8: Read-only input def_start3 ---");
    i_def_start3 = 2'b10;
    wait_posedge;
    apb_read(PARA_DEF_OFFSET, rdata);
    `ASSERT_EQ(rdata[28:27], 2'b10, "def_start3 input should be readable");

    // Test 9: Address error (misaligned address)
    $display("\n--- Test 9: Address error test ---");
    @(negedge i_bus_clk);
    i_psel    = 1'b1;
    i_penable = 1'b0;
    i_pwrite  = 1'b1;
    i_paddr   = 16'h1;  // Misaligned
    i_pstrb   = 4'b1111;
    wait_posedge;
    @(negedge i_bus_clk);
    i_penable = 1'b1;
    wait_posedge;
    while (!o_pready) wait_posedge;
    `ASSERT_EQ(o_pslverr, 1'b1, "pslverr should be 1 for misaligned address");
    i_psel = 1'b0;

    // Test 10: Protection error
    $display("\n--- Test 10: Protection error test ---");
    i_protect_en = 1'b1;
    i_pprot      = 3'b010;  // Non-secure access
    apb_write(PARA_ABC_OFFSET, 32'h0);
    `ASSERT_EQ(o_pslverr, 1'b1, "pslverr should be 1 for protection violation");
    i_protect_en = 1'b0;
    i_pprot      = 3'b000;


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
    #PARA_CLK_PERIOD
    i_hw_we_def_start2    = 1'b0;
    i_hw_we_def_start3    = 1'b0;
    `ASSERT_EQ(o_def_start2, 1'b1, "def_start2 should be 1 after HW write");
    `ASSERT_EQ(o_def_start3, 2'b11, "def_start3 should be 11 after HW write");
    
    // APB writes 1 only to clear abc_start2, not abc_start4
    apb_write(PARA_DEF_OFFSET, 32'h28000000);  // Write 1 to bit[29] only
    `ASSERT_EQ(o_def_start2, 1'b0, "def_start2 should be 0 after clearing by APB");
    `ASSERT_EQ(o_def_start3, 2'b10, "only def_start3[0] is cleared");
    

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

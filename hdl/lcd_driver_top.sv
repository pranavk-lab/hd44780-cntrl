`timescale 1ns / 1ns

module lcd_driver_top #(
    parameter int DATA_WIDTH = 8,
    parameter int INSTR_WIDTH = 10,
    parameter int PRESCALER_WIDTH = 16
) (

    input clk_i,
    input rst_ni,

    // AHBLite interface for regbus
    input        [11:0] haddr_i,
    input        [ 1:0] htrans_i,
    input        [31:0] hwdata_i,
    input               hwrite_i,
    output logic [31:0] hrdata_o,
    output logic        hready_out_o,
    output logic        hresp_o,

    // LCD interface
    input  [DATA_WIDTH-1:0] data_in_i,
    output [DATA_WIDTH-1:0] data_out_o,
    output                  data_oe_o,
    output                  rs_o,
    output                  rwb_o,
    output                  e_o
);

  localparam bit [INSTR_WIDTH-1:0] NopCmd = {INSTR_WIDTH{1'b1}};

  logic                       output_en;

  logic [    INSTR_WIDTH-1:0] lcd_instr;  // {RS, RWB, DB7, DB6/ADD6,..., DB0/ADD0}
  logic                       phy_ready;
  logic                       valid_instr;

  logic [PRESCALER_WIDTH-1:0] prescaler_10ns;
  logic [     DATA_WIDTH-1:0] lcd_rdata;

  logic                       phy_enable;
  logic                       pc_clear;

  // Register block
  lcd_driver_cfg #(
      .DATA_WIDTH(DATA_WIDTH),
      .INSTR_WIDTH(INSTR_WIDTH),
      .PRESCALER_WIDTH(PRESCALER_WIDTH)
  ) lcd_driver_cfg (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // AHBLite
      .haddr_i     (haddr_i),
      .hrdata_o    (hrdata_o),
      .hresp_o     (hresp_o),
      .htrans_i    (htrans_i),
      .hwdata_i    (hwdata_i),
      .hwrite_i    (hwrite_i),
      .hready_out_o(hready_out_o),

      .prescaler_10ns_o(prescaler_10ns),
      .phy_enable_o    (phy_enable),
      .lcd_instr_o     (lcd_instr),
      .phy_ready_i     (phy_ready),
      .valid_instr_o   (valid_instr),
      .lcd_rdata_i     (lcd_rdata)
  );

  // PHY block
  HD44780U_phy #(
      .DATA_WIDTH(DATA_WIDTH),
      .INSTR_WIDTH(INSTR_WIDTH),
      .PRESCALER_WIDTH(PRESCALER_WIDTH)
  ) lcd_phy (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      // Register config
      .prescaler_10ns_i(prescaler_10ns),
      .phy_enable_i    (phy_enable),
      .lcd_data_o      (lcd_rdata),

      // LCD instruction interface
      .lcd_instr_i  (lcd_instr),
      .valid_instr_i(valid_instr),
      .ready_instr_o(phy_ready),

      // LCD IO interface
      .data_in_i (data_in_i),
      .data_out_o(data_out_o),
      .data_oe_o (data_oe_o),
      .rs_o      (rs_o),
      .rwb_o     (rwb_o),
      .e_o       (e_o)
  );

endmodule

`timescale 1ns/1ns

module lcd_driver_top #(
    parameter DATA_WIDTH = 8,
    parameter INSTR_WIDTH = 10,
    parameter PRESCALER_WIDTH = 16
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

localparam NOP_CMD = {INSTR_WIDTH{1'b1}};

logic output_en;

logic [INSTR_WIDTH-1:0] lcd_instr; // {RS, RWB, DB7, DB6/ADD6,..., DB0/ADD0}
logic 					phy_ready;
logic 					valid_instr;

logic [PRESCALER_WIDTH-1:0] prescaler_100n;
logic [     DATA_WIDTH-1:0] lcd_rdata;

logic phy_enable;
logic pc_clear;

assign data_oe_o = {DATA_WIDTH{output_en}};

// Register block
lcd_driver_cfg #(
    .DATA_WIDTH(DATA_WIDTH), 
    .INSTR_WIDTH(INSTR_WIDTH), 
    .PRESCALER_WIDTH(PRESCALER_WIDTH)
) lcd_driver_cfg (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AHBLite
    .haddr_i      (haddr_i     ),
    .hrdata_o     (hrdata_o    ),
    .hresp_o      (hresp_o     ),
    .htrans_i     (htrans_i    ),
    .hwdata_i     (hwdata_i    ),
    .hwrite_i     (hwrite_i    ),
    .hready_out_o (hready_out_o),

    .prescaler_100n (prescaler_100n),
    .phy_enable     (phy_enable    ),
    .lcd_instr      (lcd_instr     ),
    .phy_ready      (phy_ready     ),	
    .valid_instr    (valid_inst    ),
    .lcd_rdata      (lcd_rdata     )
);

// PHY block
HD44780U_phy #(
    .DATA_WIDTH(DATA_WIDTH), 
    .INSTR_WIDTH(INSTR_WIDTH), 
    .PRESCALER_WIDTH(PRESCALER_WIDTH)
) lcd_phy (
    .clk_i  (clk_i ),
    .rst_ni (rst_ni),

    // Register config
    .auto_busy_check (auto_busy_check),
    .prescaler_100n  (prescaler_100n ),
    .phy_enable      (phy_enable     ),
    .lcd_rdata       (lcd_rdata      ),

    // LCD instruction interface
    .lcd_instr   (lcd_instr  ),
    .valid_instr (valid_instr),
    .ready_instr (phy_ready  ),

    // LCD IO interface
    .data_in_i  (data_in_i ),
    .data_out_o (data_out_o),
    .data_oe_o  (output_en ),
    .rs_o       (rs_o      ),
    .rwb_o      (rwb_o     ),
    .e_o        (e_o       )
);

endmodule

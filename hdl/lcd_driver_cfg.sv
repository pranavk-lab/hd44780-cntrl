`timescale 1ns/1ns

`include "lcd_cfg_register_defines.v"

module lcd_driver_cfg #(
parameter DATA_WIDTH = 8,
parameter INSTR_WIDTH = 10,
parameter LCD_INSTR_CNT = 80,
parameter PRESCALER_WIDTH = 16,
parameter CHECK_BUSY_ERROR_WIDTH = 16,
parameter INSTR_ADDR_WIDTH = 6
) (
    input clk_i,
    input rst_ni,

    // ahblite bus
    // TODO: Convert addr bit width to parameter
    input        [11:0] haddr_i,
    input        [31:0] hwdata_i,
    input               hwrite_i,
    input        [ 1:0] htrans_i,
    output logic [31:0] hrdata_o,
    output logic        hready_out_o,
    output logic        hresp_o,

    input                              phy_read_i,
    input        [     DATA_WIDTH-1:0] lcd_rdata_i,
    output logic [PRESCALER_WIDTH-1:0] prescaler_10ns_o,
    output logic                       phy_enable_o,
    output logic [    INSTR_WIDTH-1:0] lcd_instr_o,
    output logic                       valid_instr_o
);

logic read_trans;
logic write_trans;
logic wait_trans;
logic ahblite_error_state;
logic invalid_trans;

logic [11:0] haddr_capture;
logic        hwrite_capture;
logic        valid_trans;
logic        lcd_instr_overwritten;

typedef enum {OKAY, ERROR} resp_state_e;

resp_state_e curr_resp_state, next_resp_state;

//******************************************************************************
// Capture incomming AHBlite command
//******************************************************************************
always_comb begin
    if (valid_instr_o) begin 
        if (phy_read_i) begin 
            lcd_instr_overwritten = 1'b0;
        end else begin 
            lcd_instr_overwritten = 1'b1;
        end 
    end else begin 
        lcd_instr_overwritten = 1'b0;
    end 
end 

assign valid_trans = htrans_i[1] & !(hwrite_i & lcd_instr_overwritten);

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        haddr_capture  <= '0;
        hwrite_capture <= '0;
    end else if (valid_trans) begin
        haddr_capture  <= haddr_i;
        hwrite_capture <= hwrite_i;
    end else begin
        hwrite_capture <= 1'b0;
    end
end

// Add other invalid/error transactions. 
assign invalid_trans = (
    htrans_i[1] & 
    (
        // Out of boundry error
        (haddr_i > `LCD_DRIVER_MAX_OFFSET)
    )
); 

always_ff @(posedge clk_i) begin : sm_sync
    if (!rst_ni) begin 
        curr_resp_state <= OKAY;
    end else begin 
        curr_resp_state <= next_resp_state;
    end
end 

always_comb begin 
    hready_out_o      = 1'b1;
    hresp_o           = 1'b0;
    next_resp_state = curr_resp_state;

    case(curr_resp_state)

        OKAY: begin 
            if (invalid_trans) begin 
                hresp_o           = 1'b1;
                hready_out_o      = 1'b0;
                next_resp_state = ERROR;
            end 
        end

        ERROR: begin 
            hresp_o           = 1'b1;
            next_resp_state = OKAY;
        end 

        default: next_resp_state = OKAY;
    endcase
end


//******************************************************************************
// R/W registers
//******************************************************************************
logic lcd_ctrl_wen;
logic lcd_ctrl_ren;
logic lcd_instr_ren;
logic lcd_instr_wen;
logic prescaler_wen;
logic prescaler_ren;
logic busy_loop_cnt_max_wen;
logic busy_loop_cnt_max_ren;


assign lcd_ctrl_wen = (haddr_capture == `LCD_CTRL_OFFSET) &  hwrite_capture & !hresp_o;
assign lcd_ctrl_ren = (haddr_capture == `LCD_CTRL_OFFSET) & !hwrite_capture & !hresp_o;

assign lcd_instr_wen = (haddr_capture == `LCD_INSTR_OFFSET) &  hwrite_capture & !hresp_o;
assign lcd_instr_ren = (haddr_capture == `LCD_INSTR_OFFSET) & !hwrite_capture & !hresp_o;

assign prescaler_wen = (haddr_capture == `PRESCALER_OFFSET) &  hwrite_capture & !hresp_o;
assign prescaler_ren = (haddr_capture == `PRESCALER_OFFSET) & !hwrite_capture & !hresp_o;

assign busy_loop_cnt_max_wen = (haddr_capture == `BUSY_LOOP_CNT_MAX_OFFSET) &  hwrite_capture & !hresp_o;
assign busy_loop_cnt_max_ren = (haddr_capture == `BUSY_LOOP_CNT_MAX_OFFSET) & !hwrite_capture & !hresp_o;


//******************************************************************************
// Read only registers
//******************************************************************************
logic lcd_rdata_ren;
logic error_ren;

assign lcd_rdata_ren = (haddr_capture == `LCD_RDATA_OFFSET) & !hwrite_capture & !hresp_o;
assign error_ren     = (haddr_capture == `LCD_ERROR_OFFSET) & !hwrite_capture & !hresp_o;

//******************************************************************************
// Write Registers
//******************************************************************************
always_ff @(posedge clk_i) begin : lcd_ctrl_write_reg
    if (!rst_ni) begin
        phy_enable_o <= '0;
    end else if (lcd_ctrl_wen) begin
        phy_enable_o <= hwdata_i[0];
    end
end

always_ff @(posedge clk_i) begin: lcd_instr_write_reg
    if (!rst_ni) begin 
        lcd_instr_o   <= '0;
        valid_instr_o <= 1'b0;
    end else if (lcd_instr_wen) begin 
        lcd_instr_o   <= hwdata_i[INSTR_WIDTH-1:0]; 
        valid_instr_o <= 1'b1;
    end else if (phy_read_i) begin 
        valid_instr_o <= 1'b0;
    end
end

always_ff @(posedge clk_i) begin : prescaler_100n_reg
    if (!rst_ni) begin
        prescaler_10ns_o <= 'd10;
    end else if (prescaler_wen) begin
        prescaler_10ns_o <= hwdata_i[PRESCALER_WIDTH-1:0];
    end
end

//******************************************************************************
// Read Registers
//******************************************************************************
always_comb begin : read_reg
    case(1)
        lcd_ctrl_ren            : hrdata_o = {30'h0, phy_read_i, phy_enable_o};
        lcd_instr_ren           : hrdata_o = {{(32-INSTR_WIDTH){1'b0}}, lcd_instr_o};
        lcd_rdata_ren           : hrdata_o = {{(32-DATA_WIDTH){1'b0}}, lcd_rdata_i};
        prescaler_ren           : hrdata_o = {{(32-PRESCALER_WIDTH){1'b0}}, prescaler_10ns_o};
        default                 : hrdata_o = 32'h0;
    endcase
end

endmodule
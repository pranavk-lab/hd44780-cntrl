`timescale 1ns/1ns
// Hitachi 44780U phy 

module HD44780U_phy #(
    parameter DATA_WIDTH = 8,
    parameter INSTR_WIDTH = 10,
    parameter PRESCALER_WIDTH = 16,
    parameter CHECK_BUSY_ERROR_WIDTH = 16
) (
    input clk,
    input nrst,

    // Register config
    input                              auto_busy_check,
    input        [PRESCALER_WIDTH-1:0] prescaler_10n,
    input                              phy_enable,
    output logic [     DATA_WIDTH-1:0] lcd_rdata,

    // LCD instruction interface
    input        [INSTR_WIDTH-1:0] lcd_instr, // {RS, RWB, DB7, DB6/ADD6,..., DB0/ADD0}
    input                          valid_instr,
    output logic                   ready_instr,

    // LCD IO interface
    output logic [DATA_WIDTH-1:0] data_out,
    input        [DATA_WIDTH-1:0] data_in,
    output logic                  rs,
    output logic                  rwb,
    output logic                  e,
    output logic                  data_oe
);


localparam ADDR_SETUP_CNT = 6;
localparam EN_PW_CNT = 45;
localparam E_CYCLE_CNT = 100;
localparam RDATA_DELAY_CNT = 36;



logic [6:0] cnt;
logic [PRESCALER_WIDTH-1:0] prescaler_cnt;

typedef enum {
    IDLE, 
    ADDR_PHASE, 
    WDATA_PHASE, 
    RDATA_PHASE, 
    CAPTURE_RDATA, 
    E_HOLD
} state;

state curr_state, next_state;

// Register outputs
logic [           1:0] lcd_addr;
logic [DATA_WIDTH-1:0] lcd_wdata;
logic                  lcd_enable;
logic                  lcd_write_en;

always_ff @(posedge clk or negedge nrst) begin 
    if (!nrst) begin 
        rs       <= 1'b0;
        rwb      <= 1'b0;
        e        <= 1'b0;
        data_out <= '0;
        data_oe  <= '0;
    end else begin 
        {rs, rwb} <= lcd_addr;
        e         <= lcd_enable;
        data_out  <= lcd_wdata;
        data_oe   <= lcd_write_en;
    end 
end 

// Capture read data
always_ff @(posedge clk or negedge nrst) begin 
    if (!nrst) begin 
        lcd_rdata <= '0;
    end else if (next_state == CAPTURE_RDATA) begin 
        lcd_rdata <= data_in;
    end 
end 

// Pipeline
logic pipe_in_advance;
logic pipe_in_valid;

assign pipe_in_advance = valid_instr & ready_instr;
assign ready_instr = pipe_in_valid & phy_enable;
always_ff @(posedge clk or negedge nrst) begin
    if (!nrst) begin
        pipe_in_valid <= 1'b0;
    end else if (pipe_in_advance) begin
        pipe_in_valid <= 1'b0;
    end else if (curr_state == E_HOLD && (cnt == (E_CYCLE_CNT - EN_PW_CNT) - 1)) begin
        pipe_in_valid <= 1'b1;
    end
end

// Instruction capture
logic rs_instr;
logic rwb_instr;
logic [INSTR_WIDTH-3:0] wdata_instr;

always_ff @(posedge clk or negedge nrst) begin
    if (!nrst) begin
        rs_instr    <= '0;
        rwb_instr   <= '0;
        wdata_instr <= '0;
    end	else if (pipe_in_advance) begin
        rs_instr    <= lcd_instr[INSTR_WIDTH-1];
        rwb_instr   <= lcd_instr[INSTR_WIDTH-2];
        wdata_instr <= lcd_instr[INSTR_WIDTH-3:0];
    end
end

// Counter to meet lcd timing requirements
always_ff @(posedge clk or negedge nrst) begin 
    if (!nrst) begin 
        cnt           <= '0;
        prescaler_cnt <= '0;
    end else if ((next_state == IDLE) || (next_state != curr_state))begin 
        cnt           <= '0;
        prescaler_cnt <= '0;
    end else if (prescaler_cnt == prescaler_10n-1) begin 
        cnt           <= cnt + 1;
        prescaler_cnt <= '0;
    end else begin 
        prescaler_cnt <= prescaler_cnt + 1;
    end
end 

// PHY state machine 
always_ff @(posedge clk or negedge nrst) begin 
    if (!nrst) begin 
        curr_state <= IDLE;
    end else begin 
        curr_state <= next_state;
    end 
end 

always_comb begin 
    lcd_enable   = 1'b0;
    lcd_addr     = {rs, rwb};
    lcd_wdata    = data_out;
    lcd_write_en = data_oe;
    next_state   = curr_state;

    case (curr_state) 
        IDLE: begin 
            lcd_write_en = 1'b0;
            if (pipe_in_advance) begin 
                next_state = ADDR_PHASE;
            end 
        end 

        ADDR_PHASE: begin 
            // Update the address lines 
            lcd_addr = {rs_instr, rwb_instr};
            if (cnt == ADDR_SETUP_CNT) begin 
                next_state = WDATA_PHASE;
                if (rwb_instr) begin 
                    next_state = RDATA_PHASE;
                end
            end
        end 

        WDATA_PHASE: begin 
            lcd_enable = 1'b1;
            // Update the data out
            lcd_wdata    = wdata_instr;
            lcd_write_en = 1'b1;
            if (cnt == EN_PW_CNT) begin 
                next_state = E_HOLD;
            end 
        end 

        RDATA_PHASE: begin 
            lcd_enable   = 1'b1;
            lcd_write_en = 1'b0;
            if (cnt == RDATA_DELAY_CNT) begin 
                next_state = CAPTURE_RDATA;
            end 
        end 

        CAPTURE_RDATA: begin 
            lcd_enable = 1'b1;
            if (cnt == (EN_PW_CNT - RDATA_DELAY_CNT)) begin 
                next_state = E_HOLD;
            end 
        end 

        E_HOLD: begin 
            if (cnt == (E_CYCLE_CNT - EN_PW_CNT)) begin 
                next_state = IDLE;
                if (pipe_in_advance) begin 
                    next_state = ADDR_PHASE;
                end 
            end 
        end 

        default: begin 
            next_state = IDLE;
        end 
    endcase
end 

endmodule

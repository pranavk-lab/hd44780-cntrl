`timescale 1ns/1ns
// Hitachi 44780U phy 

module HD44780U_phy #(
    parameter DATA_WIDTH = 8,
    parameter INSTR_WIDTH = 10,
    parameter PRESCALER_WIDTH = 16,
    parameter CHECK_BUSY_ERROR_WIDTH = 16
) (
    input clk_i,
    input rst_ni,

    // Register config
    input        [PRESCALER_WIDTH-1:0] prescaler_10ns_i,
    input                              phy_enable_i,
    output logic [     DATA_WIDTH-1:0] lcd_data_o,

    // LCD instruction interface
    input        [INSTR_WIDTH-1:0] lcd_instr_i, // {RS, RWB, DB7, DB6/ADD6,..., DB0/ADD0}
    input                          valid_instr_i,
    output logic                   ready_instr_o,

    // LCD IO interface
    output logic [DATA_WIDTH-1:0] data_out_o,
    input        [DATA_WIDTH-1:0] data_in_i,
    output logic                  rs_o,
    output logic                  rwb_o,
    output logic                  e_o,
    output logic                  data_oe_o
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
} state_e;

state_e curr_state, next_state;

// Register outputs
logic [           1:0] lcd_addr;
logic [DATA_WIDTH-1:0] data_out_d;
logic                  e_d;
logic                  data_oe_d;

always_ff @(posedge clk_i or negedge rst_ni) begin 
    if (!rst_ni) begin 
        rs_o       <= 1'b0;
        rwb_o      <= 1'b0;
        e_o        <= 1'b0;
        data_out_o <= '0;
        data_oe_o  <= '0;
    end else begin 
        {rs_o, rwb_o} <= lcd_addr;
        e_o           <= e_d;
        data_out_o    <= data_out_d;
        data_oe_o     <= data_oe_d;
    end 
end 

// Capture read data
always_ff @(posedge clk_i or negedge rst_ni) begin 
    if (!rst_ni) begin 
        lcd_data_o <= '0;
    end else if (next_state == CAPTURE_RDATA) begin 
        lcd_data_o <= data_in_i;
    end 
end 

// Pipeline
logic pipe_in_advance;
logic pipe_in_valid;

assign pipe_in_advance = valid_instr_i & ready_instr_o;
assign ready_instr_o = pipe_in_valid & phy_enable_i;
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
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

always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        rs_instr    <= '0;
        rwb_instr   <= '0;
        wdata_instr <= '0;
    end	else if (pipe_in_advance) begin
        rs_instr    <= lcd_instr_i[INSTR_WIDTH-1];
        rwb_instr   <= lcd_instr_i[INSTR_WIDTH-2];
        wdata_instr <= lcd_instr_i[INSTR_WIDTH-3:0];
    end
end

// Counter to meet lcd timing requirements
always_ff @(posedge clk_i or negedge rst_ni) begin 
    if (!rst_ni) begin 
        cnt           <= '0;
        prescaler_cnt <= '0;
    end else if ((next_state == IDLE) || (next_state != curr_state))begin 
        cnt           <= '0;
        prescaler_cnt <= '0;
    end else if (prescaler_cnt == prescaler_10ns_i-1) begin 
        cnt           <= cnt + 1;
        prescaler_cnt <= '0;
    end else begin 
        prescaler_cnt <= prescaler_cnt + 1;
    end
end 

// PHY state machine 
always_ff @(posedge clk_i or negedge rst_ni) begin 
    if (!rst_ni) begin 
        curr_state <= IDLE;
    end else begin 
        curr_state <= next_state;
    end 
end 

always_comb begin 
    e_d   = 1'b0;
    lcd_addr   = {rs_o, rwb_o};
    data_out_d = data_out_o;
    data_oe_d  = data_oe_o;
    next_state = curr_state;

    case (curr_state) 
        IDLE: begin 
            data_oe_d = 1'b0;
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
            e_d = 1'b1;
            // Update the data out
            data_out_d = wdata_instr;
            data_oe_d  = 1'b1;
            if (cnt == EN_PW_CNT) begin 
                next_state = E_HOLD;
            end 
        end 

        RDATA_PHASE: begin 
            e_d       = 1'b1;
            data_oe_d = 1'b0;
            if (cnt == RDATA_DELAY_CNT) begin 
                next_state = CAPTURE_RDATA;
            end 
        end 

        CAPTURE_RDATA: begin 
            e_d = 1'b1;
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

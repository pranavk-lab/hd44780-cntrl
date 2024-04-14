`ifndef INCLUDE_LCD_CFG_REGISTER_DEFINES_V
`define INCLUDE_LCD_CFG_REGISTER_DEFINES_V

`define LCD_CTRL_OFFSET             12'h0
`define LCD_INSTR_OFFSET            12'h4
`define LCD_RDATA_OFFSET            12'h8
`define PRESCALER_OFFSET            12'hc
`define LCD_DRIVER_MAX_OFFSET       `PRESCALER_OFFSET + 4
`define OUT_BOUNDS_OFFSET           12'hfff

`define LCD_CTRL_RW_MASK            32'h0000_0007
`define LCD_INSTR_RW_MASK           32'h0000_003f
`define LCD_RDATA_RW_MASK           32'h0000_0000
`define PRESCALER_RW_MASK           32'h0000_ffff

`define LCD_CTRL_RESET_VAL          32'h0000_0000
`define LCD_INSTR_RESET_VAL         32'h0000_0000
`define LCD_RDATA_RESET_VAL         32'h0000_0000
`define PRESCALER_RESET_VAL         32'h0000_000a

`endif // INCLUDE_LCD_CFG_REGISTER_DEFINES_V

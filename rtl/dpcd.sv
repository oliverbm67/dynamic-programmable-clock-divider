module dpcd #(
    parameter DIV_CTRL_SIZE_P = 4)
    (
    input  logic                            clk_src,
    input  logic                            rst_n,
    input  logic [DIV_CTRL_SIZE_P - 1:0]    div_ctrl,
    output logic                            clk_out
);

/*
The necessary number of delay states corresponds to
the number of possible values of div_ctrl : 2**DIV_CTRL_SIZE_P
even or odd divisor values are treated separately so we divide the total number of state in half
a division by a factor or 2 or 3 is also handled separately so need -2
*/
localparam DELAY_STATES_C = 2 ** (DIV_CTRL_SIZE_P - 1) - 2;
/* 
To insure proper frequency division updates, need to add 2 bits (for even/odd and division by 2 or 3)
to the control register compared to only use what is necessary for delay states
*/
localparam CTRL_REG_SIZE_C = $clog2(DELAY_STATES_C) + 2;

logic [CTRL_REG_SIZE_C - 1 :0]              div_ctrl_reg;
logic                                       rst;                        // inverted polarity reset
logic                                       clk_src_n;                  // inverted input clock
logic                                       clk_divided;                // clock after division
logic                                       clk_feedback;               // feedback signal to main flip-flop
logic                                       clk_select_mux;             // the clock coming from shift register
logic                                       rst_divider_reg_n;          // asynchronous reset for divider_reg
logic                                       divider_reg;                // main flip-flop to generate the output clock
logic [DELAY_STATES_C - 1 :0]               shift_reg;                  // register to create the delay for division
logic                                       negedge_clear_reg;          // used for odd division factor
logic                                       negedge_delay_reg;          // used for odd division factor

// Inverted input signals
assign rst =  ~rst_n;
assign clk_src_n =  ~clk_src;

// Register the control input
// clocked on the OUTPUT clock to avoid glitch
// A remapping between input control and div_ctrl_reg is necessary
// bit[0] make the switch between even and odd division factor
// bit[1] can only be used for division by 2 or 3 and not for anything else
// thus shifting the value of div_ctrl from one bit
always_ff @(posedge clk_divided or negedge rst_n) begin
    if (!rst_n) begin
        div_ctrl_reg <= 'h0;
    end else begin
        if (div_ctrl[DIV_CTRL_SIZE_P - 1 :2] == 'h0) begin      // special case, direct copy
            div_ctrl_reg[CTRL_REG_SIZE_C - 1 :2] <= 'h0;
            div_ctrl_reg[1:0] <= div_ctrl[1:0];
        end else begin
            div_ctrl_reg[0] <= div_ctrl[0];                 // keep unchanged LSB because of custom control
            div_ctrl_reg[1] <= 1'b0;
            div_ctrl_reg[CTRL_REG_SIZE_C - 1 :2] <= div_ctrl[DIV_CTRL_SIZE_P - 1 :1] - 'h1;
        end
    end
end

// shift registers to create the delay for the division
always_ff @(posedge clk_src or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg <= 'h0;
    end else begin
        shift_reg <= {shift_reg[DELAY_STATES_C - 2:0], divider_reg};
    end
end

/*
Divier reg : the main register generating the output clock
use an asynchronous reset to switch state on negedge for odd
division factor
*/
assign rst_divider_reg_n = ~(rst | negedge_clear_reg);

always_ff @(posedge clk_src or negedge rst_divider_reg_n) begin
    if (!rst_divider_reg_n) begin
        divider_reg <= 1'b0;
    end else begin
        divider_reg <= clk_feedback;
    end
end

assign clk_divided = divider_reg;

// Clock select feedback
always_comb begin
    if (div_ctrl_reg[CTRL_REG_SIZE_C - 1 : 2] == 'h0) begin
        clk_select_mux = divider_reg;
    end else begin
        clk_select_mux = shift_reg[div_ctrl_reg[CTRL_REG_SIZE_C - 1 : 2] - 1];
    end
end
// Clock inversion for odd division
always_ff @(posedge clk_src or negedge div_ctrl_reg[0]) begin
    if (!div_ctrl_reg[0]) begin
        negedge_delay_reg <= 1'b0;
    end else begin
        negedge_delay_reg <= clk_select_mux;
    end
end
always_ff @(posedge clk_src_n or negedge div_ctrl_reg[0]) begin
    if (!div_ctrl_reg[0]) begin
        negedge_clear_reg <= 1'b0;
    end else begin
        negedge_clear_reg <= negedge_delay_reg;
    end
end
always_comb begin
    if (div_ctrl_reg[0]) begin
        clk_feedback = ~negedge_delay_reg;
    end else begin
        clk_feedback = ~clk_select_mux;
    end
end

// Clock out multiplexer
// bypass the divider when ctrl = 0
// provide the inverted clock when ctrl = 1
always_comb begin
    if (div_ctrl_reg == 'h0) begin
        clk_out = clk_src;
    end else if (div_ctrl_reg == 'h1) begin
        clk_out = ~clk_src;
    end else begin
        clk_out = divider_reg;
    end
end

endmodule
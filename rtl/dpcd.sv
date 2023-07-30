module dpcd (
    input  logic            clk_src,
    input  logic            rst_n,
    input  logic [3:0]      div_ctrl,
    output logic            clk_out
);

logic [4:0]     div_ctrl_reg;
logic           rst;            // inverted polarity reset
logic           clk_src_n;      // inverted input clock
logic           clk_divided;
logic           clk_feedback;
logic           clk_select_mux;
logic           rst_divider_reg_n;  // asynchronous reset for divider_reg
logic           divider_reg;
logic [7:0]     shift_reg;
logic           negedge_clear_reg;
logic           negedge_delay_reg;

// Inverted input signals
assign rst =  ~rst_n;
assign clk_src_n =  ~clk_src;

// Register the control input
// clocked on the OUTPUT clock to avoid glitch
// A remapping between input control and div_ctrl_reg is necessary
// bit[0] make the switch between even and odd
// bit[1] can only be used for division by 2 or 3 and not for anything else
// thus shifting the value of div_ctrl from one bit
always_ff @(posedge clk_divided or negedge rst_n) begin
    if (!rst_n) begin
        div_ctrl_reg <= 'h0;
    end else begin
        case (div_ctrl)
            4'h0 : div_ctrl_reg <= 'h0;
            4'h1 : div_ctrl_reg <= 'h1;
            4'h2 : div_ctrl_reg <= 'h2;
            4'h3 : div_ctrl_reg <= 'h3;
            4'h4 : div_ctrl_reg <= 'h4;
            4'h5 : div_ctrl_reg <= 'h5;
            4'h6 : div_ctrl_reg <= 'h8;
            4'h7 : div_ctrl_reg <= 'h9;
            4'h8 : div_ctrl_reg <= 'hC;
            4'h9 : div_ctrl_reg <= 'hD;
            4'hA : div_ctrl_reg <= 'h10;
            4'hB : div_ctrl_reg <= 'h11;
            4'hC : div_ctrl_reg <= 'h14;
            4'hD : div_ctrl_reg <= 'h15;
            4'hE : div_ctrl_reg <= 'h18;
            4'hF : div_ctrl_reg <= 'h19;
            default : div_ctrl_reg <= 'h0;
        endcase
    end
end

// shift registers to create the division
always_ff @(posedge clk_src or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg <= 'h0;
    end else begin
        shift_reg <= {shift_reg[6:0], divider_reg};
    end
end

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
    case (div_ctrl_reg[4:2])
        'b000: clk_select_mux = divider_reg;
        'b001: clk_select_mux = shift_reg[0];
        'b010: clk_select_mux = shift_reg[1];
        'b011: clk_select_mux = shift_reg[2];
        'b100: clk_select_mux = shift_reg[3];
        'b101: clk_select_mux = shift_reg[4];
        'b110: clk_select_mux = shift_reg[5];
        'b111: clk_select_mux = shift_reg[6];
        default:  clk_select_mux = 1'hX;
    endcase
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
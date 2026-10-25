// Align coordinates to the existing delayed video bundle (640x480, 800x525).
// Active-first coordinates: sync falls at x=656, rises at x=752.
// The official generator changes VS at HS fall, before vertical line advance;
// that edge belongs to active-first row 489, not row 490.
module lesson3_video_align (
    input clk, input rst, input hs, input vs, input de,
    input [23:0] rgb,
    output reg hs_q, output reg vs_q, output reg de_q,
    output reg [23:0] rgb_q,
    output reg [9:0] x, output reg [9:0] y,
    output wire next_line_active
);
    reg hs_d, vs_d;
    assign next_line_active = y < 479 || y == 524;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hs_d<=0; vs_d<=0; hs_q<=1; vs_q<=1; de_q<=0;
            rgb_q<=0; x<=0; y<=489;
        end else begin
            hs_d<=hs; vs_d<=vs;
            hs_q<=hs; vs_q<=vs; de_q<=de; rgb_q<=rgb;
            if (!hs_d && hs) x<=752;
            else x <= x==799 ? 0 : x+1'b1;
            if (vs_d && !vs) y<=489;
            else if (x==799) y<= y==524 ? 0 : y+1'b1;
        end
    end
endmodule
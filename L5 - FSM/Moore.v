module Moore (
    input wire clk, reset,
    input wire [2:0] q,
    output reg [2:0] w
);
  
  localparam r1 = 0;
  localparam r2 = 1;
  localparam r3 = 2;

  reg [1:0] state, next_state;

  always @(posedge(clk)) begin
    if (reset) begin
      state <= r1;
    end else begin
      state <= next_state;
    end
  end
  
  always @(q, state) begin
    case (state)
      r1: begin
        w = 4;
        if (q[0]) begin
          next_state = r1; 
        end else if (q[1]) begin
          next_state = r3; 
        end else if (q[2]) begin
          next_state = r2; 
        end else begin
          next_state = state; 
        end
      end
      r2: begin
        w = 1;
        if (q[0]) begin
          next_state = r3; 
        end else if (q[1]) begin
          next_state = r2; 
        end else if (q[2]) begin
          next_state = r2; 
        end else begin
          next_state = state; 
        end       
      end
      r3: begin
        w = 2;
        if (q[0]) begin
          next_state = r1; 
        end else if (q[1]) begin
          next_state = r3; 
        end else if (q[2]) begin
          next_state = r2; 
        end else begin
          next_state = state; 
        end 
      end
      default: begin 
        w = 0;
        next_state = state; 
      end
    endcase
  end

 endmodule

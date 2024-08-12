module N (
    input wire x,
    output wire y
);

assign #1 y = ~x;

endmodule


module NOA22 (
    input wire a, b, c, d,
    output wire y
);

 assign #4 y = ~((a & b) | (c & d));

endmodule

module D_ff (
    input wire D, C,
    output wire Q
);

  wire [5:0] z;

  N n0 (
      .x(C),
      .y(z[0])
  );
  N n1 (
      .x(z[0]),
      .y(z[1])
  );
  N n2 (
      .x(z[2]),
      .y(z[3])
  );
  N n3 (
      .x(z[4]),
      .y(z[5])
  );
  NOA22 noa0 (
      .a(z[3]),
      .b(z[1]),
      .c(z[0]),
      .d(D),
      .y(z[2])
  );
  NOA22 noa1 (
      .a(z[5]),
      .b(z[0]),
      .c(z[3]),
      .d(z[1]),
      .y(z[4])
  );
  N n4 (
      .x(z[4]),
      .y(Q)
  );

endmodule


module D_ff_alg (
    input wire D, C,
    output reg Q
);

  reg temp;

  always @(posedge C) begin
      #7 Q <= D;
  end 

endmodule
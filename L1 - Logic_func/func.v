module func (
  input x1, x2, x3 ,x4, 
  output reg y1, y2, y3
);

always @(*)
  begin
    y1 <= x1&x3 | x1&x2&x4 | x2&x3&x4;
    y2 <= x1&x2&(~x3)&(~x4) | x1&(~x2)&(~x3)&x4 | (~x1)&x2&(~x3)&x4 | (~x1)&x2&x3&(~x4);
    y3 <= x2&(~x4) | x1&(~x2)&x4 | (~x2)&(~x3)&(x4);
  end
endmodule

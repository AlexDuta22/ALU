module ALU(
    input [15:0] operand1,
    input [15:0] operand2,
    input [3:0] operation, // 0: Adunare, 1: Scadere, 2:inmultire 3:impartire 
    //4:shift st op1 5:shift dr op1 6:shift st op2 7:shift dr op2 8:and 9:or 10:exor
    output reg [15:0] result,
    output reg [15:0] rest_result,
    output reg zero // Indicator pentru rezultatul zero
);
wire [15:0] add_result, sub_result, mul_result, div_result,rest, and_result, or_result, exor_result;
wire [15:0] result_op1_left, result_op1_right, result_op2_left, result_op2_right;


    BitAdder adder_inst(
        .operand1(operand1),
        .operand2(operand2),
        .sum(add_result)
    );
    BitSubtractor subtractor_inst(
        .descazut(operand1),
        .scazator(operand2),
        .difference(sub_result)
    );
    BitMultiplier multiplier_inst(
        .multiplicand(operand1),
        .multiplier(operand2),
        .product(mul_result)
    );
    Divider divider_inst(
        .dividend(operand1),
        .divisor(operand2),
        .quotient(div_result),
        .remainder(rest)
    );
    
    ShiftRegister shift_op1_left(
        .data_in(operand1),
        .shift_left(1),
        .shift_right(0), // Nu shiftam la dreapta operandul 1
        .data_out(result_op1_left)
    );
    
    ShiftRegister shift_op1_right(
        .data_in(operand1),
        .shift_left(0),
        .shift_right(1), 
        .data_out(result_op1_right)
    );
    
    ShiftRegister shift_op2_left(
        .data_in(operand2),
        .shift_left(1), // Nu shiftam la stanga operandul 2
        .shift_right(0),
        .data_out(result_op2_left)
    );

    ShiftRegister shift_op2_right(
        .data_in(operand2),
        .shift_left(0), // Nu shiftam la stanga operandul 2
        .shift_right(1),
        .data_out(result_op2_right)
    );
    
    BitwiseOperations operation_inst(
        .operand1(operand1),
        .operand2(operand2),
        .result_and(and_result),
        .result_or(or_result),
        .result_xor(exor_result)
    );

always @(*) begin
    case(operation)
        4'b0000: begin
                    result = add_result; // Adunare
                 end
        4'b0001: result = sub_result; // Scadere
        4'b0010: result = mul_result; // inmultire
        4'b0011: begin 
                  result = div_result;
                  rest_result = rest;
                end // impartire
        4'b0100: result = result_op1_left;
        4'b0101: result = result_op1_right;
        4'b0110: result = result_op2_left;
        4'b0111: result = result_op2_right;
        4'b1000: result = and_result; // And
        4'b1001: result = or_result;  // Or
        4'b1010: result = exor_result;// Exor
        default: result = 16'h0000; // Valoare implicita
    endcase
    
    if(result == 16'b0) // Verificam daca rezultatul este zero
        zero = 1'b1;
    else
        zero = 1'b0;
end

endmodule

module BitAdder(
    input [15:0] operand1,
    input [15:0] operand2,
    output [15:0] sum
);

reg [15:0] result;
reg carry;
integer i;

always @* begin
    carry = 0;
    for (i = 0; i < 16; i = i + 1) begin
        result[i] = operand1[i] ^ operand2[i] ^ carry;
        carry = (operand1[i] & operand2[i]) | (operand1[i] & carry) | (operand2[i] & carry);
    end
end

assign sum = result;

endmodule

//scaderea pe biti

module BitSubtractor(
    input [15:0] descazut,   // Descazutul (num?rul din care se scade)
    input [15:0] scazator,   // Scaz?torul (num?rul care se scade)
    output [15:0] difference // Diferen?a
);

reg borrow; // Wire pentru imprumut
reg [15:0] result;
integer i;

always @* begin
borrow = 0;
for (i = 0; i < 16; i = i + 1) begin : subtractor_loop
        result[i] = descazut[i] ^ scazator[i] ^ borrow; // Diferenta pentru bitul curent
        borrow = (~descazut[i] & scazator[i]) | ((~descazut[i] | scazator[i]) & borrow); // Calculul imprumutului pentru urmatorul bit
    end
end

assign difference = result;
endmodule


//inmultirea pe biti

module BitMultiplier(
    input [15:0] multiplicand,
    input [15:0] multiplier,
    output reg [31:0] product
);

reg [31:0] partial_products [15:0];

integer i, j;

always @(*) begin
    for (i = 0; i < 16; i = i + 1) begin
        partial_products[i] = {16{multiplier[i]}} & (multiplicand << i);
    end
end

always @(*) begin
    product = 32'b0;
    for (j = 0; j < 16; j = j + 1) begin
        product = product + partial_products[j];
    end
end

endmodule


//impartirea pe biti

module Divider (
    input [15:0] dividend,
    input [15:0] divisor,
    output reg [15:0] quotient,
    output reg [15:0] remainder
);

reg [15:0] A;
reg [15:0] Q;
reg [15:0] M;

integer i;

always @* begin
    A = 0;
    Q = dividend;
    M = divisor;

    // Algoritmul de impartire cu restaurare
    for (i = 0; i < 16; i = i + 1) begin
        {A[15:0], Q[15:1]} = {A[14:0], Q[15:0]};
        Q[0]=0; // Deplasam catul la stanga cu un bit
        A = A - M;
        // Verificam daca divizorul poate fi scazut din restul curent
        if (A[8] == 0) begin
            Q[0] = 1; // Setam bitul corespunzator in cat
        end else begin
            A = A + M; // Adaugam divizorul la rest
        end
    end

    // Ajustam catul si restul pentru rezultatele finale
    quotient = Q;
    remainder = A;
end

endmodule


//shiftare la stanga sau la dreapta

module ShiftRegister(
    input [15:0] data_in,
    input shift_left, // Semnal pentru shiftare la stanga
    input shift_right, // Semnal pentru shiftare la dreapta
    output reg [15:0] data_out
);

always @(*) begin
    if (shift_left) begin
        data_out = {data_in[14:0], 1'b0}; // Shiftare la stanga
    end else if (shift_right) begin
        data_out = {1'b0, data_in[15:1]}; // Shiftare la dreapta
    end else begin
        data_out = data_in; // Nicio shiftare
    end
end

endmodule


//codul pentru operatiile and, or si xor

module BitwiseOperations(
    input [15:0] operand1,
    input [15:0] operand2,
    output [15:0] result_and,
    output [15:0] result_or,
    output [15:0] result_xor
);

assign result_and = operand1 & operand2; // Operatia AND
assign result_or = operand1 | operand2; // Operatia OR
assign result_xor = operand1 ^ operand2; // Operatia XOR

endmodule

`timescale 1ns / 1ps

module ALU_Testbench;

    // Parametri pentru simulare
    parameter CLK_PERIOD = 10; // Perioada de ceas

    // Definirea semnalelor
    reg [15:0] operand1;
    reg [15:0] operand2;
    reg [3:0] operation;
    wire [15:0] result;
    wire [15:0] rest_result;
    wire zero;

    // Instantierea modulului ALU
    ALU DUT (
        .operand1(operand1),
        .operand2(operand2),
        .operation(operation),
        .result(result),
        .rest_result(rest_result),
        .zero(zero)
    );

    // Generare ceas
    reg clk = 0;
    always #((CLK_PERIOD)/2) clk = ~clk;

    // Teste
    initial begin
        // Test 1: Adunare 5 + 3
        operand1 = 4'b0101; // 5 in binar
        operand2 = 4'b0011; // 3 in binar
        operation = 2'b00; // Cod pentru adunare
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 1: 5 + 3 = %d", result);

        // Test 2: Scadere 5 - 3
        operand1 = 4'b0101; // 5 in binar
        operand2 = 4'b0011; // 3 in binar
        operation = 2'b01; // Cod pentru scadere
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 2: 5 - 3 = %d", result);

        // Test 3: inmultire 5 * 3
        operand1 = 4'b0101; // 5 in binar
        operand2 = 4'b0011; // 3 in binar
        operation = 2'b10; // Cod pentru inmultire
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 3: 5 * 3 = %d", result);

        // Test 4: impartire 7 / 2
        operand1 = 4'b0111; // 7 in binar
        operand2 = 4'b0010; // 2 in binar
        operation = 2'b11; // Cod pentru impartire
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 4: 7 / 2 = %d %d", result, rest_result);
        
        //Test 5: Shift stanga 5
        operand1 = 4'b0101; // 5 in binar
        operation = 3'b100; // Cod pentru shift stanga op1
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 5: 5 << 1 = %d", result);

        //Test 6: Shift dreapta 5
        operand1 = 4'b0101; // 5 in binar
        operation = 3'b101; // Cod pentru shift dreapta op1
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 6: 5 >> 1 = %d", result);
        
        //Test 7: Shift stanga 3
        operand2 = 4'b0011; // 3 in binar
        operation = 3'b110; // Cod pentru shift stanga op2
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 7: 3 << 1 = %d", result);

        //Test 8: Shift dreapta 5
        operand2 = 4'b0011; // 3 in binar
        operation = 3'b111; // Cod pentru shift dreapta op2
        #100; // Asteapta o perioada pentru a permite ALU sa calculeze rezultatul
        $display("Test 8: 3 >> 1 = %d", result);
        
        //Test 9: And 5&3
        operand1 = 4'b0101;
        operand2 = 4'b0011; // 3 in binar
        operation = 4'b1000;
        #100
        $display("Test 9: 5 & 3 = %d", result);
        
        //Test 10: Or 5|3
        operand1 = 4'b0101;
        operand2 = 4'b0011; // 3 in binar
        operation = 4'b1001;
        #100
        $display("Test 10: 5 | 3 = %d", result);
        
        //Test 11: Xor 5^3
        operand1 = 4'b0101;
        operand2 = 4'b0011; // 3 in binar
        operation = 4'b1010;
        #100
        $display("Test 11: 5 ^ 3 = %d", result);
        $finish;
    end

endmodule
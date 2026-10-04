`timescale 1ns/1ps

// mode 00=HR (atanh(2^-i)); mode 01/10=LV/LR (2^-i).

module angle_lut_rom #(parameter WIDTH=32, parameter FRAC=13) (
    input signed [7:0] iteration_i,                                   //itteration number (I)
    input [1:0] mode,                                                 //cordic mode
    output reg signed [WIDTH-1:0] angle                               //gives back the fixed point Constants

    //DOING CORDIC OPERATION
);

    integer i;
    reg signed [31:0] q13;

    always @* begin
    
        i = iteration_i;

        q13 = 0;                     //CONTAINS THE VALUE NEEDED FOR CORDIC

        if (mode == 2'b00) begin          
//MODE-1:
    00-> Hyperbolic Mode -> ATANH(2^-I)  {CORDIC for E^X}    (WE CALCULATE THIS ATANH(2^-I) AND REP IN Q3.13 THEN STORE IT IN A ROM {PRECALCULATED})
            
            case (i)
                1: q13=4500; 2: q13=2092; 3: q13=1029; 4: q13=513;
                5: q13=256;  6: q13=128;  7: q13=64;   8: q13=32;
                9: q13=16;   10:q13=8;    11:q13=4;    12:q13=2;
                default: q13=0;
            endcase

        end else if (FRAC == 13) begin
//MODE-2:
                01/10-> Linear Mode (LV,LR) -> "CALCULATE 2^-I"   {CORDIC for MAC or Division }   WHICH CAN BE DONE BY RIGHT SHIFT (8192 >>> i)(NO MASSIVE HARDWARE SO NO NEED PRECALCULATEDVALUE AS ROM)

            if (i < 0) q13 = 8192 <<< (-i);                   //IF I<0 LEFT SHIFT 8192 BY I (mul by 2)
            else if (i < 31) q13 = 8192 >>> i;                //IF I>0 RIGHT SHIFT 8192 BY I (div by 2)    (IE IF 0<I<31 THIS CONDTN SATISFIES)
            else q13 = 0;

        end else begin

            if (i < 0) q13 = (1 <<< FRAC /*gives 2^FRAC*/ ) <<< (-i) ;                      //2^i* 2^frac
            else if (i < 31) q13 = (1 <<< FRAC) >>> i;                                          //2^frac/2^i     then the q13 will be in fixed point format of 2^-i

            else q13 = 0;

        end

        angle = q13;                          //THE OUTPUT
    end
endmodule


/* it gen precalculated angle numbers for cordic engine    */



/*

" **fixed point value = real int * 2^frac** "

frac=8
how to represent 1.256 in fixed point = 1.256*2^8 = 322 = 1 . 0100 0010
1*2^0 + . 0/2 +1/2^2 +0/2^3 +0/2^4 + 0/2^5 +0/2^6 +1/2^7 +0/2^8 = 1.257..... 

*/ 

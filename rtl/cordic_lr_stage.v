`timescale 1ns/1ps

Y_IN + X_IN*2^-I AND iteration_i = I NOT -I

module cordic_lr_stage #(parameter WIDTH=32, parameter FRAC=13) (       //w=32 , frac=13 means fractional part is 13 bit, 1 bit sign, 18 bit integer 
    
    //the width determines the input of y,x,z. 
    input signed [WIDTH-1:0] x_in, y_in, z_in,       //ITS IN THE FIXED POINT FORMAT ITSELF (ACC TO THE FRAC)                    
    input signed [7:0] iteration_i,                                //XIN x 2^I @ I<0 IE;-VE ==> XIN >>> I      WHO CALCULATES THIS I
    output reg signed [WIDTH-1:0] x_next, y_next, z_next           //NEXT MEANS
);


    
    reg signed [WIDTH-1:0] xterm;                       //xterm = XIN x 2^-I
    reg signed [WIDTH+3:0] xterm_wide;
    reg signed [WIDTH+3:0] y_wide;

    wire signed [WIDTH-1:0] angle;

    angle_lut_rom #(WIDTH,FRAC) lut( iteration_i , 2'b10 /* LINEAR MODE */ , angle /*2^-iteration_i );     //THE ANGLE IS USED TO MAKE z_next = ZIN - ANGLE  THE ANGLE TELLS HOW MUCH IS MULTIPLIED IN ZIN SO WE NEED TO REDUCE IT IN ZIN AND GIVE TO z_next

    /* EX:- 4 + 3*0.75 = 6.25    
        STAGE-1)z_in = O.75 AND x_in = 3 AND iteration_i = 1 , Y=4
        STAGE-1) y_next= 4+3*0.5 (DUE TO I=1) = 5.5 ----SO NOW WE HAVE COMPLETED ONLY 0.5 MULTIPLICATION WE NEED TO PERFORM 0.75-0.5 (ANGLE) = 0.25 MULTIPLICATION SO Z IN UPDATED IE; z_next = ZIN - ANGLE

        STAGE-2)z_in = O.25 (WHICH IS z_next OF STAGE-1) AND x_in = 3 AND iteration_i = 2 (2^-2 = 0.25) , Y =5.5    "THIS iteration_i IS GEN SOMEWHERE ACC TO z_in"
        STAGE-2) y_next= 5.5+3*0.25 (DUE TO I=2) = 6.25 ----z_next = z_in - ANGLE => 0.25 - 0.25 = 0
    */

    always @* begin
        
//X * 2^ -iteration_i..........

        if (iteration_i < 0) begin     //NOW ITTERATION I IS -VE SO 2^-(-I) = 2^I IE; SO WE NEED TO MULTIPLY IE LEFT SHIFT TO GET THE "C".    
           
//FOR FPx4 MODE           
            if (WIDTH == 4) begin

            //xterm_wide is 4 bits extra
                xterm_wide = {{4{x_in[WIDTH-1]}},x_in};        //w=4bits means x=4bits then we need to make it as 8 bits so we extens the sign bits.       

                xterm = xterm_wide <<< (-iteration_i);                            //GETTING THE LEFT SHIFT VALUE FOR MULTIPLY

            end else begin

                xterm = x_in <<< (-iteration_i);
            end

        end else xterm = x_in >>> iteration_i;                  //IE; I IS +VE SO -I IS -VE IE; WE NEED TO DIVIDE.
        x_next = x_in;                                        //THIS WILL REMAIN CONST FOR ALL Z_IN AND z_next


//

        if ((WIDTH == 4) && (iteration_i < 0)) begin

            y_wide = {{4{y_in[WIDTH-1]}},y_in};                      //sign extension

            if (z_in >= 0) begin                                 //IF z_in IS +VE  
                y_wide = y_wide + xterm_wide;               //Y = Y + X *(+Z) => Y = Y + X * Z
                y_next = y_wide;                        //the msb side is truncated due to sign extended 

                z_next = z_in - angle;                      //TOI DRIVE THE Z TOWARDS 0

            end else begin                                       //IF z_in IS -VE 
                y_wide = y_wide - xterm_wide;               //Y = Y + X *(-Z) => Y = Y - X * Z
                y_next = y_wide;

                z_next = z_in + angle;                     
            end

        end else if (z_in >= 0) begin                            //IF WIDTH != 4 OR iteration_i IS +VE
            y_next = y_in + xterm; 
            z_next = z_in - angle;                               

        end else begin
            y_next = y_in - xterm; 
            z_next = z_in + angle;

        end
    end
endmodule


/*
    it performs multiplication using SHIFTER AND ADDER

    THIS CORDIC DOES THIS "ynext​ = yin​ + xin​*2^−i" AND AFTER MULTIPLE CYCLES THAT ADDS UP AND BECOMES " yout ​= yinitial​ + xin​*zin​" ( MAC )

    -> Y = X+AB THIS IS CONVENTIONAL MAC HARDWARE A,P,T IS VERY HIGH

    CORDIC:- B x C = SHIFT + ADD/SUBTRACT

        MAKE C AS 2^I  (BCS MULTIPLYING WITH 2 IS JUST SHIFTING) EX:-\
            13 x 5 = 13 x 2^2 + 13 x 2^0 

    ->2^I ==> I IS -VE NA RIGHT SHIFT (IE; DIV) ELSE LEFT SHIFT 

        WE GO FOR BxC = BX2^-I => 2^-I = C (-I => DIV DUE TO WE GET SOMETHING LIKE THIS 0.0028398 AS C (DUE TO WE R DOING FIXED POINT CALCULATION))
        EX:- 4x0.75 = 4x0.5 +4x0.25 = 4x2^-1 (I=1) + 4x2^-2 (I=2) => 4>>1 +4>>2


*/
/*
    WIDTH=3 AND FRAC=0 IT RANGES -4 TO +3    (-VE HIGHER NO TO +VE LOWER)
    WIDTH=3 AND FRAC=1 (2^-1 = 0.5) -> INT BITS WIDTH IS 2=> IT RANGES -2 TO 1 + (1-0.5)
    WIDTH=3 AND FRAC=2 (2^-2 = 0.25) -> INT BITS WIDTH IS 1=> IT RANGES 1 TO 0 + (1-0.25) 

                        WIDTH       FRAC = W/2 
            FxP4           4           2
            FxP8           8           4
            FxP16         16           8
            FxP32         32          16

0101.101 => 8   4   2   1 . 1/2  1/4  1/8

"fixed point value = real int * 2^frac"
frac=8
how to represent 1.256 in fixed point = 1.256*2^8 = 322 = 1 . 0100 0010
1*2^0 + . 0/2 +1/2^2 +0/2^3 +0/2^4 + 0/2^5 +0/2^6 +1/2^7 +0/2^8 = 1.257..... 

*/
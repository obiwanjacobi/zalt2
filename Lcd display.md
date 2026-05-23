# LCD Display

From product page (aliExpress) (I have the 7 inch!):

- Display Size: 5.0 inch TFT LCD
- Resolution: 800*480 pixels
- Interface: 16Bit parallel interface
- Driver IC: SSD1963
- Display Color: 16BIT RGB 65K color
- Smart Electronics Experiment: Switch And Sensor For Arduino STM32

**5 Inch Color Screen**
- Customizable Design: This 5 inch color display module is fully customizable, allowing for a personalized touch to your smart electronics experiments.
- Versatile Interface: With a 16Bit parallel interface, this 5 inch color screen module is compatible with a wide range of microcontrollers like Arduino and STM32.
- High Resolution Display: Featuring a crystal-clear 800*480 resolution, this 5 inch color display module ensures sharp visuals for your projects.
- Robust Controller: Equipped with a reliable SSD1963 Driver IC, the 5 inch color screen module ensures stable and responsive performance.
- Advanced Color Depth: Boasting 16BIT RGB 65K color, the 5 inch color display module delivers vibrant and lifelike visuals for your creations.

**Versatile Display Module for Smart Electronics**
The 5 inch TFT LCD HD Color Resistive Touch Screen Display Module is a versatile component designed for smart electronics projects. With its 800*480 resolution, this display module offers a crisp and clear viewing experience, perfect for various applications. The 16BIT RGB 65K color palette ensures vibrant and true-to-life visuals, making it an ideal choice for creative projects that require a high level of color accuracy. The module's 16Bit parallel interface is compatible with a wide range of microcontrollers, including Arduino, 51 AVR, and STM32, making it a versatile addition to your electronic toolkit.

**Enhanced User Interaction with Resistive Touch**
The module's resistive touch functionality provides a reliable and responsive user interface, allowing for easy interaction with applications. Whether you're building a home automation system or an interactive kiosk, this touch screen display module will enhance user experience by enabling direct input and control. The customizable nature of the display module also allows for tailored solutions to fit specific project requirements, making it a valuable asset in the field of smart electronics.

**Designed for Ease of Use and Integration**
Designed with ease of use in mind, the 5 inch color display module is a breeze to integrate into your existing projects. The module's compact size and lightweight design make it an ideal choice for portable and space-constrained applications. The high-quality display and responsive touch functionality make it a standout component for any project that demands a professional and user-friendly interface. With its adaptability and compatibility with a range of microcontrollers, this module is a go-to solution for both hobbyists and professionals alike.

---

https://www.lcdwiki.com/7.0inch_16BIT_Module_SSD1963

SSD1963 driver example:
https://github.com/fbrausse/ssd1963
https://github.com/Bodmer/TFT_eSPI

```c
TFT_CS = 0;
TFT_Set_Index_Ptr(0x26);//    Set Gamma Curve
//  TFT_Write_Command_Ptr(0x01); // Gamma curve selection =0
// TFT_Write_Command_Ptr(0x02);   // Gamma curve selection =1
// TFT_Write_Command_Ptr(0x04);  // Gamma curve selection =2
TFT_Write_Command_Ptr(0x08);  // Gamma curve selection =3

TFT_Set_Index_Ptr(0x0B);          //SET SCAN MODE
TFT_Write_Command_Ptr(0x00);      //SET TFT MODE   top to bottom, left to right normal etc

TFT_Set_Index_Ptr(0x0A);
TFT_Write_Command_Ptr(0x1C);         //Power Mode

TFT_Set_Index_Ptr(0x3A);          //SET Pixel Format
// TFT_Write_Command_Ptr(0x50);       //16 bit pixel
TFT_Write_Command_Ptr(0x60);       //18 bit pixel
// TFT_Write_Command_Ptr(0x70);       //24 bit pixel

TFT_Set_Index_Ptr(0xF0);      //  Set Pixel Data Interface
TFT_Write_Command_Ptr(0x03);   // 16-bit (565 format)   011 16-bit (565 format)

TFT_Set_Index_Ptr(0xBC);   //Set Post Proc
TFT_Write_Command_Ptr(0x40); //40 Set the contrast value
TFT_Write_Command_Ptr(0x80); //80 Set the brightness value
TFT_Write_Command_Ptr(0x40); //40 Set the saturation value
TFT_Write_Command_Ptr(0x01);  //1 Enable the postprocessor

TFT_Set_Index_Ptr(0xE2);
TFT_Write_Command_Ptr(60);    //35 PLLclk = REFclk * 36 (360MHz)
TFT_Write_Command_Ptr(5);     // SYSclk = PLLclk / 3  (120MHz)
TFT_Write_Command_Ptr(0x54);  // validate M and N      dec 84

TFT_Set_Index_Ptr(0xe0);
TFT_Write_Command_Ptr(0x01); // START PLL
Delay_50us(); Delay_50us(); // Wait 100us 

TFT_Set_Index_Ptr(0xe0);
TFT_Write_Command_Ptr(0x03); // LOCK PLL

TFT_Set_Index_Ptr(0xB0);          //SET LCD MODE   SIZE !!
TFT_Write_Command_Ptr(0x19);       //19 TFT panel data width - Enable FRC or dithering for color depth enhancement
TFT_Write_Command_Ptr(0x20);       //SET TFT MODE & hsync+Vsync+DEN MODE   20  or 00
TFT_Write_Command_Ptr(0x03);      //SET horizontal size=800+1 HightByte   !
TFT_Write_Command_Ptr(0x21);      //SET horizontal size=800+1 LowByte
TFT_Write_Command_Ptr(0x01);      //SET vertical size=480+1 HightByte
TFT_Write_Command_Ptr(0xE1);      //SET vertical size=480+1 LowByte
TFT_Write_Command_Ptr(0x00);      //Even line RGB sequence / Odd line RGB sequence RGB

TFT_Set_Index_Ptr(0xe6);       // pixel clock frequency
TFT_Write_Command_Ptr(0x04);   // LCD_FPR = 290985 = 33.300 Mhz Result for 7" Display
TFT_Write_Command_Ptr(0x70);
TFT_Write_Command_Ptr(0xA9);

TFT_Set_Index_Ptr(0xB4);            // Set Horizontal Period   (Front Porch)
TFT_Write_Command_Ptr(0x03);        // High byte of horizontal total period (display + non-display)
TFT_Write_Command_Ptr(0x5E);       // Low byte of the horizontal total period (display + non-display)
TFT_Write_Command_Ptr(0x00);        //High byte of the non-display period between the start of the horizontal sync (LLINE) signal and the first display data.
TFT_Write_Command_Ptr(0x46); //**   // 46 Low byte of the non-display period between the start of the horizontal sync (LLINE) signal and the first display data
TFT_Write_Command_Ptr(0x09);       //Set the vertical sync pulse width 
TFT_Write_Command_Ptr(0x00);       //SET Hsync pulse start position //00
TFT_Write_Command_Ptr(0x00);
TFT_Write_Command_Ptr(0x00);       //SET Hsync pulse subpixel start position 

//   ** too small will give you half a PICTURE !!

TFT_Set_Index_Ptr(0xB6);          //Set Vertical Period
TFT_Write_Command_Ptr(0x01);      //01 High byte of the vertical total (display + non-display) period in lines was 1F5
TFT_Write_Command_Ptr(0xFE);      //F4 Low byte F5 INCREASES SYNC TIME AND BACK PORCH 1D WAS 00 OR f5
TFT_Write_Command_Ptr(0x00);      // 00
TFT_Write_Command_Ptr(0x0C);      //0C =12 The non-display period in lines between the start of the frame and the first display data in line.
TFT_Write_Command_Ptr(0x00);      //Set the vertical sync pulse width (LFRAME) in lines.
TFT_Write_Command_Ptr(0x00);      //SET Vsync pulse start position
TFT_Write_Command_Ptr(0x00);

// flip
TFT_Set_Index_Ptr(0x36);      //  Flip left to right      REQUIRED FOR ??
TFT_Write_Command_Ptr(0x02);
TFT_CS = 1;
```

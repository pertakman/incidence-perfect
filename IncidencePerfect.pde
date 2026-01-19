#include <LiquidCrystal.h>
#include <EEPROM.h>
#include <Accelerometer.h>

// LIS3LV02DQ accelerometer pinout
#define DATAOUT 11 //MOSI
#define DATAIN  12 //MISO 
#define SPICLOCK  13 //SCK
#define SLAVESELECT 10// SS (LIS3LV02DQ, active low)

// LCD pinout
#define V0 3
#define D0 4
#define D1 5
#define D2 6
#define D3 7
#define RS 8
#define ENABLE 9

// Analog pin used for the 5 key pad
#define KEYPIN 0
#define KEYLEFT  10
#define KEYRIGHT 20
#define KEYUP    30
#define KEYDOWN  40
#define KEYSEL   50
#define KEYINV   60   // Invalid key value
char oldKey = KEYINV;
long keyDownTime; // time the key was pressed down

Accelerometer acc(DATAOUT, DATAIN, SPICLOCK, SLAVESELECT); // Initialize accelerometer
LiquidCrystal lcd(RS, ENABLE, D0, D1, D2, D3); // Initialize lcd

byte currentAngle = 0; // Currently active angle 
boolean holdAngles[2] = {false, false}; // Flags for angle hold 
boolean relativeAngles[2] = {false, false}; // Flags for relative angles
float pitchAngle, rollAngle, thetaAngle; // pitch and roll angle variables
float accelerationmagnitude;

void setup()
{
  Serial.begin(9600); // Open serial port
  analogWrite(V0, 128); // Set LCD contrast level
  lcd.begin(16, 2); // Specify LCD dimensions width/height
  lcdSplashScreen(); // Show splash screen for 2 seconds
  if (!acc.query()) // Make sure accelerometer is present
    lcdFaultySensor();
  acc.mode(0,relativeAngles[0]); // Set pitch mode to absolute angles
  acc.mode(1,relativeAngles[1]); // Set roll mode to absolute angles
}

void loop()
{
  char key = KeyScan(); // Detect if a button is pressed 
  if (key != oldKey) // Make sure that this key was just pressed  
  {
    keyDownTime = millis(); // Key pressed time stamp
    oldKey = key; // Update oldKey
    switch(key)
    {
      case KEYLEFT:
        relativeAngles[currentAngle] = !relativeAngles[currentAngle];
        acc.mode(currentAngle,relativeAngles[currentAngle]);
        break;
      case KEYRIGHT:
        relativeAngles[currentAngle] = !relativeAngles[currentAngle];
        acc.mode(currentAngle,relativeAngles[currentAngle]);
        break;
      case KEYSEL:
        holdAngles[currentAngle] = !holdAngles[currentAngle];
        break;
      case KEYUP:
        if (currentAngle == 0) currentAngle++;
        else currentAngle--;
        break;
      case KEYDOWN:
        if (currentAngle == 0) currentAngle++;
        else currentAngle--;
        break;
    }
  }
  else if (key == KEYSEL && millis()-keyDownTime > 2000)
  {
    calibrationMenu();
    holdAngles[currentAngle] = false;
  }
  
  // Update accelerometer and update pitch and roll unless hold is turned on
  int N = 10;
  float pitch = 0;
  float roll = 0;
  float theta = 0;
  accelerationmagnitude = 0;
  for (int i = 0; i < N; i++)
  {
    acc.update();
    pitch += acc.pitch();
    roll += acc.roll();
    theta += acc.theta();
    accelerationmagnitude += acc.accelerationmagnitude();
  }
  pitch = pitch/N;
  roll = roll/N;
  theta = theta/N;
  accelerationmagnitude = accelerationmagnitude/N;

  if (!holdAngles[0]) pitchAngle = pitch;
  if (!holdAngles[1]) rollAngle = roll;
  if (!holdAngles[2]) thetaAngle = theta;
  acc.dump();
  
  /*acc.update();
  if (!holdAngles[0]) pitchAngle = acc.pitch();
  if (!holdAngles[1]) rollAngle = acc.roll();
  acc.milligee();
  acc.dump();*/
  
  lcdMeasurement(); // Show measurement on LCD
  delay(100);
}

// Display splash screen on LCD
void lcdSplashScreen()
{
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("Incidence");
  lcd.setCursor(0,1);
  lcd.print("Perfect v1.1b");
  delay(2000);
}

// Display error message - Faulty sensor on LCD
void lcdFaultySensor()
{
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("Error message:");
  lcd.setCursor(0,1);
  lcd.print("Faulty sensor");
  delay(2000);
  while(1 == 1)
  {
  }
}

// Display pitch & roll measurement on LCD 
void lcdMeasurement()
{
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("Pitch: ");
  lcdPrintDouble(pitchAngle,1);
  if (holdAngles[0]) lcd.print("H");
  lcd.setCursor(0,1);
  lcd.print("Roll:  ");
  lcdPrintDouble(rollAngle,1);
  if (holdAngles[1]) lcd.print("H");
  for (int i = 0; i < 2; i++)
  {
    lcd.setCursor(15,i);
    if (relativeAngles[i]) lcd.print("R");
    else lcd.print("A");
  }
  lcd.setCursor(15,currentAngle);
  lcd.blink();
}

// Calibration menu
void calibrationMenu()
{
  int currentAxis = 0; // Set current axis to x-axis

  lcdCalibration(currentAxis); // display calibration menu on LCD
  
  // Make sure KEYSEL has been released
  char key;
  do
  {
     key = KeyScan();
  } while (key != KEYINV);
  oldKey = key;


  while (1 == 1)
  {
    char key = KeyScan(); // Detect if a button is pressed 
    if (key != oldKey) // Make sure that this key was just pressed
    {
      keyDownTime = millis();
      oldKey = key;
      switch(key)
      {
        case KEYLEFT:
          break;
        case KEYRIGHT:
          break;
        case KEYSEL:
          acc.getacal(currentAxis);  
          break;
        case KEYUP:
          currentAxis--;
          if (currentAxis < 0) currentAxis = 3;
          break;
        case KEYDOWN:
          currentAxis++;
          if (currentAxis > 3) currentAxis = 0;
          break;
      }
    }
    else if (key == KEYLEFT && millis()-keyDownTime > 2000)
    {
      acc.calibrate();
      break;
    }
    lcdCalibration(currentAxis); // display calibration menu on LCD
    delay(100);
  }
}

// Display calibration menu on LCD 
void lcdCalibration(int currentAxis)
{
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("Calibration Menu");
  lcd.setCursor(0,1);
  if (currentAxis == 0)
  {
    lcd.print("X:");
    for (int i = 0; i < 3; i++)
    {
      lcd.print(acc._acal[i][0]);
      if (i != 2)
        lcd.print(",");
    }
  }
  if (currentAxis == 1)
  {
    lcd.print("Y:");
    for (int i = 0; i < 3; i++)
    {
      lcd.print(acc._acal[i][1]);
      if (i != 2)
        lcd.print(",");
    }
  }
  if (currentAxis == 2)
  {
    lcd.print("Z:");
    for (int i = 0; i < 3; i++)
    {
      lcd.print(acc._acal[i][2]);
      if (i != 2)
        lcd.print(",");
    }
  }
  if (currentAxis == 3)
  {
    lcd.print("-Z:");
    for (int i = 0; i < 3; i++)
    {
      lcd.print(acc._acal[i][3]);
      if (i != 2)
        lcd.print(",");
    }
  }
}

// Prints val on a ver 0012 text lcd with number of decimal places determined by precision
// precision is a number from 0 to 6 indicating the desired decimial places
// example: lcdPrintDouble( 3.1415, 2); // prints 3.14 (two decimal places)
void lcdPrintDouble(double val, byte precision)
{
  if(val < 0.0)
  {
    lcd.print("-");
    val = -val;
  }
  else
    lcd.print(" ");

  lcd.print (int(val));  // Prints the int part
  if( precision > 0)
  {
    lcd.print("."); // Print the decimal point
    unsigned long frac;
    unsigned long mult = 1;
    byte padding = precision -1;
    while(precision--)
      mult *=10;
    if(val >= 0)
      frac = (val - int(val)) * mult;
    else
      frac = (int(val)- val ) * mult;
    unsigned long frac1 = frac;
    while(frac1 /= 10)
      padding--;
    while(padding--)
      lcd.print("0");
    lcd.print(frac,DEC) ;
  }
}

// Scan the key pin and determine which key was pressed. Then return a code specifying each key
// There is a fuzzy range for each key. This is a central space for all key presses. That way it's
// easy to tweak these values if need be.
char KeyScan()
{
   int val, val2, diff, key;
   val = analogRead(KEYPIN);
   delay(20);
   val2 = analogRead(KEYPIN);
   key = KEYINV;
   diff = abs(val - val2);
   if (diff < 12)
   {
	if (val > 412 && val < 620) key = KEYLEFT; // 500
	if (val >= 0 && val < 68) key =  KEYRIGHT; // 0
	if (val > 69 && val < 230) key =  KEYSEL; // 137
	if (val > 231 && val < 411) key =  KEYUP; // 323
	if (val > 621 && val < 881) key =  KEYDOWN; // 740
   }
   return key;
}

// Repeatedly call KeyScan until a valid key press occurs
char PollKey()
{
  char key;
  do
  {
     key = KeyScan();
  } while (key == KEYINV);
  return key;
}

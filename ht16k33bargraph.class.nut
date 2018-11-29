// CONSTANTS
// HT16K33 registers and HT16K33-specific variables
const HT16K33_BAR_CLASS_REGISTER_DISPLAY_ON  = "\x81";
const HT16K33_BAR_CLASS_REGISTER_DISPLAY_OFF = "\x80";
const HT16K33_BAR_CLASS_REGISTER_SYSTEM_ON   = "\x21";
const HT16K33_BAR_CLASS_REGISTER_SYSTEM_OFF  = "\x20";
const HT16K33_BAR_CLASS_DISPLAY_ADDRESS      = "\x00";
const HT16K33_BAR_CLASS_I2C_ADDRESS          =  0x70;

// Convenience constants for bar colours
const HT16K33_BAR_CLASS_LED_OFF = 0;
const HT16K33_BAR_CLASS_LED_RED = 1;
const HT16K33_BAR_CLASS_LED_YELLOW = 2;
const HT16K33_BAR_CLASS_LED_AMBER = 2;
const HT16K33_BAR_CLASS_LED_GREEN = 3;

class HT16K33Bargraph {

    // Squirrel class for 24-bar bi-color LED bargraph display
    // driven by Holtek's HT16K33 controller, as used in the
    // Adafruit Bi-Color (Red/Green) 24-Bar Bargraph w/I2C Backpack Kit
    // https://www.adafruit.com/products/1721
    // Bus: I2C
    // Availibility: Device
    // Copyright (c) 2015-18 Tony Smith (@smittytone)

    static VERSION = "2.0.0";

    // Class private properties
    _buffer = null;
    _led = null;
    _ledAddress = null;
    _barZeroByChip = true;
    _debug = false;
    _logger = null;

    constructor(i2cbus = null, i2cAddress = HT16K33_BAR_CLASS_I2C_ADDRESS, debug = false) {
        // Parameters:
        //   1. Whichever configured imp I2C bus is to be used for the HT16K33
        //   2. The I2C address from the datasheet (0x70)
        //   3. Boolean, set/unset for debugging messages
        // Returns:
        //   The instance

        if (i2cbus == null) throw "HT16K33Bar() requires a non-null Imp I2C bus";

        // Save bar graph's I2C details
        _led = i2cbus;
        _ledAddress = i2cAddress << 1;

        // Set the debugging flag
        if (typeof debug != "bool") debug = false;
        _debug = debug;

        // Select logging target, which stored in '_logger', and will be 'seriallog' if 'seriallog.nut'
        // has been loaded BEFORE HT16K33SegmentBig is instantiated on the device, otherwise it will be
        // the imp API object 'server'
        if ("seriallog" in getroottable()) { _logger = seriallog; } else { _logger = server; }

        // The buffer stores the colour values for each block of the bar
        _buffer = [0x0000, 0x0000, 0x0000];
    }

    function init(brightness = 15, barZeroByChip = true) {
        // Parameters:
        //   1. Integer, the initial brightness, 1-15 (default: 15)
        //   2. Boolean, to select whether bar zero is at the chip end of
        //      the board (true) or at the far end (false):
        //       ___________________________
        //      | o  [CHIP] [BARGRAPH LEDs] |
        //       ---------------------------
        //      bar number   0 . . . . . 23    barZeroByChip = true
        //      bar number   23 . . . . . 0    barZeroByChip = false
        // Returns:
        //   The instance

        local t = typeof barZeroByChip;

        if (t != "bool") {
            if (t == "float" || t == "integer") {
                barZeroByChip = (barZeroByChip.tointeger() == 0) ? false : true;
            } else {
                barZeroByChip = true;
            }
        }

        _barZeroByChip = barZeroByChip;

        // Power the display
        powerUp();

        // Set the brightness
        setBrightness(brightness);

        // Return the instance
        return this;
    }

    function fill(barNumber, ledColor) {
        // Fills all the bars up to and including the specified bar with the specified color
        // Parameters:
        //   1. Integer, the highest bar number to be lit (0-23)
        //   2. Integer, the colour of the bar
        // Returns:
        //   The instance

        if (barNumber < 0 || barNumber > 23) {
            _logger.error("HT16K33Bargraph.fill() passed out of range (0-23) bar number");
            return null;
        }

        if (ledColor < LED_OFF || ledColor > LED_GREEN) {
            _logger.error("HT16K33Bargraph.fill() passed out of range (0-2) LED colour");
            return null;
        }

        barNumber = barNumber.tointeger();

        if (_barZeroByChip) {
            barNumber = 23 - barNumber;
            for (local i = 23 ; i > barNumber ; i--) {
                _setBar(i, ledColor);
            }
        } else {
            for (local i = 0 ; i < barNumber ; i++) {
                _setBar(i, ledColor);
            }
        }

        // Return the instance
        return this;
    }

    function set(barNumber, ledColor) {
        // Sets a specified bar’s color (off, red, green or yellow)
        // Parameters:
        //   1. Integer, the highest bar number to be lit (0-23); no default
        //   2. Integer, the colour of the bar
        // Returns: 
        //   The instance

        if (barNumber < 0 || barNumber > 23) {
            _logger.error("HT16K33Bargraph.set() passed out of range (0-23) bar number");
            return null;
        }

        if (ledColor < LED_OFF || ledColor > LED_GREEN) {
            if (_debug) _logger.error("HT16K33Bargraph.set() passed out of range (0-2) LED colour");
            return null;
        }

        if (_barZeroByChip) barNumber = 23 - barNumber;
        _setBar(barNumber, ledColor);
        
        // Return the instance
        return this;
    }

    function clear() {
        // Clears the buffer but does not write it to the LED
        // Returns:
        //   The instance

        if (_debug) _logger.log("HT16K33Bargraph buffer cleared");
        _buffer = [0x0000, 0x0000, 0x0000];
        return this;
    }

    function draw() {
        // Takes the contents of internal buffer and writes it to the LED matrix
        // Returns:
        //   Nothing
        
        local dataString = HT16K33_BAR_CLASS_DISPLAY_ADDRESS;

        for (local i = 0 ; i < 3 ; i++) {
            // Each _buffer entry is a 16-bit value - convert to two 8-bit values to write
            dataString = dataString + (_buffer[i] & 0xFF).tochar() + (_buffer[i] >> 8).tochar();
        }

        _led.write(_ledAddress, dataString);
    }

    function setBrightness(brightness = 15) {
        // Called to change the display brightness
        // Parameters:
        //   1. Integer, the brightness setting (0 - 15; default: 15)
        // Returns:
        //   Nothing
        
        if (typeof brightness != "integer" && typeof brightness != "float") brightness = 15;
        brightness = brightness.tointeger();

        if (brightness > 15) {
            brightness = 15;
            if (_debug) _logger.error("HT16K33Matrix.setBrightness() brightness out of range (0-15)");
        }

        if (brightness < 0) {
            brightness = 0;
            if (_debug) _logger.error("HT16K33Matrix.setBrightness() brightness out of range (0-15)");
        }

        if (_debug) _logger.log("Brightness set to " + brightness);
        brightness = brightness + 224;

        // Write the new brightness value to the HT16K33
        _led.write(_ledAddress, brightness.tochar() + "\x00");
    }

    function setDisplayFlash(flashRate = 0) {
        // Parameters:
        //    1. Flash rate in Herz. Must be 0.5, 1 or 2 for a flash, or 0 for no flash
        // Returns:
        //    Nothing

        local values = [0, 2, 1, 0.5];
        local match = -1;
        foreach (i, value in values) {
            if (value == flashRate) {
                match = i;
                break;
            }
        }

        if (match == -1) {
            _logger.error("HT16K33Bargraph.setDisplayFlash() invalid blink frequency (" + flashRate + ")");
            return;
        }

        match = 0x81 + (match << 1);
        _led.write(_ledAddress, match.tochar() + "\x00");
        if (_debug) _logger.log(format("Display flash set to " + flashRate + " Hz"));
    }
    
    function setDebug(state = true) {
        // Enable or disable device debug logging
        // Parameters:
        //   1. Boolean, whether debug logging should be enabled. Default: true
        // Returns:
        //   Nothing

        if (typeof state != "bool") state = true;
        _debug = state;
    }

    function powerDown() {
        // Power off the display
        // Returns:
        //   Nothing
        if (_debug) _logger.log("Powering HT16K33Bargraph down");
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_DISPLAY_OFF);
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_SYSTEM_OFF);
    }

    function powerUp() {
        // Power on the display
        // Returns:
        //   Nothing
        if (_debug) _logger.log("Powering HT16K33Bargraph up");
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_SYSTEM_ON);
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_DISPLAY_ON);
    }

    // ********** Private Functions - Do Not Call **********

    function _setBar(barNumber, ledColor) {
        // Sets a specific bar to the specified color
        // Called by set() and fill()
        // Parameters:
        //   1. Integer, the chosen bar number (0 - 23)
        //   2. Integer, the LED color (0 [off], 1 [red], 2 [yellow], 3 [green])
        // Returns:
        //   Nothing
        local a = barNumber < 12 ? barNumber / 4 : (barNumber - 12) / 4;
        local b = barNumber % 4;
        
        if (barNumber >= 12) b = b + 4;

        a = a.tointeger();
        b = b.tointeger();

        if (ledColor == HT16K33_BAR_CLASS_LED_RED) {
            // Turn red LED on, green LED off
            _buffer[a] = _buffer[a] | (1 << b);
            _buffer[a] = _buffer[a] & ~(1 << (b + 8));
        } else if (ledColor == HT16K33_BAR_CLASS_LED_GREEN) {
            // Turn green LED on, red off
            _buffer[a] = _buffer[a] | (1 << (b + 8));
            _buffer[a] = _buffer[a] & ~(1 << b);
        } else if (ledColor == HT16K33_BAR_CLASS_LED_YELLOW) {
            // Turn red and green LED on
            _buffer[a] = _buffer[a] | (1 << b) | (1 << (b + 8));
        } else if (ledColor == HT16K33_BAR_CLASS_LED_OFF) {
            // Turn red and green LED off
            _buffer[a] = _buffer[a] & ~(1 << b) & ~(1 << (b + 8));
        }
    }
}

/**
 * HT16K33 registers and HT16K33-specific variables
 */ 
const HT16K33_BAR_CLASS_REGISTER_DISPLAY_ON  = "\x81";
const HT16K33_BAR_CLASS_REGISTER_DISPLAY_OFF = "\x80";
const HT16K33_BAR_CLASS_REGISTER_SYSTEM_ON   = "\x21";
const HT16K33_BAR_CLASS_REGISTER_SYSTEM_OFF  = "\x20";
const HT16K33_BAR_CLASS_DISPLAY_ADDRESS      = "\x00";
const HT16K33_BAR_CLASS_I2C_ADDRESS          =  0x70;

/**
 * Convenience constants for bar colours
 */
const HT16K33_BAR_CLASS_LED_OFF = 0;
const HT16K33_BAR_CLASS_LED_RED = 1;
const HT16K33_BAR_CLASS_LED_YELLOW = 2;
const HT16K33_BAR_CLASS_LED_AMBER = 2;
const HT16K33_BAR_CLASS_LED_GREEN = 3;

/**
 * Squirrel class for 24-bar bi-color LED bargraph display driven by Holtek's HT16K33 controller, as used in the
 * Adafruit Bi-Color (Red/Green) 24-Bar Bargraph w/I2C Backpack Kit: https://www.adafruit.com/products/1721
 *
 * Bus          I2C
 * Availibility Device
 * @author      Tony Smith (@smittytone)
 * @copyright   2015-19 Tony Smith
 * @license     MIT
 *
 * @class
 */
class HT16K33Bargraph {

    /**
     * @property {string} VERSION - The library version
     * 
     */    
    static VERSION = "2.0.0";

    // *********** Private Properties **********

    _buffer = null;
    _led = null;
    _ledAddress = null;
    _barZeroByChip = true;
    _debug = false;
    _logger = null;

    /**
     *  Instantiate the LED bargraph
     *
     *  @constructor
     *
     *  @param {imp::i2c} i2cbus       - Whichever configured imp I2C bus is to be used for the HT16K33
     *  @param {integer}  [i2cAddress] - The HT16K33's I2C address. Default: 0x70
     *  @param {bool}     [debug ]     - Set/unset to log/silence extra debug messages. Default: false
     *  
     *  @returns {instance} The instance
    */
    constructor(i2cbus = null, i2cAddress = HT16K33_BAR_CLASS_I2C_ADDRESS, debug = false) {
        if (i2cbus == null) throw "HT16K33Bargraph() requires a non-null Imp I2C bus";

        // Save bar graph's I2C details
        _led = i2cbus;
        _ledAddress = i2cAddress << 1;

        // Set the debugging flag
        if (typeof debug != "bool") debug = false;
        _debug = debug;

        // Select logging target, which stored in '_logger', and will be 'seriallog' if 'seriallog.nut'
        // has been loaded BEFORE HT16K33Bargraph is instantiated on the device, otherwise it will be
        // the imp API object 'server'
        if ("seriallog" in getroottable()) { _logger = seriallog; } else { _logger = server; }

        // The buffer stores the colour values for each block of the bar
        _buffer = [0x0000, 0x0000, 0x0000];
    }

    /**
     *  Initialize the LED bargraph
     *
     *  The 'barZeroByChip' parameter is used as follows:
     *       ___________________________
     *      | o  [CHIP] [BARGRAPH LEDs] |
     *       ---------------------------
     *      bar number   0 . . . . . 23    barZeroByChip = true
     *      bar number   23 . . . . . 0    barZeroByChip = false
     *
     *  @param {integer} brightness      - The initial display brightness, 1-15. Default: 15
     *  @param {bool}    [barZeroByChip] - Whether bar zero is at the chip end of the board (true) or at the far end. Default: true
     *  
     *  @returns {instance} The instance
    */
    function init(brightness = 15, barZeroByChip = true) {
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

    /**
     *  Set the segment LED display brightness
     *
     *  @param {integer} [brightness] - The LED brightness in range 0 to 15. Default: 15
     * 
     */
    function setBrightness(brightness = 15) {
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

    /**
     *  Set the segment LED to flash at one of three pre-defined rates
     *
     *  @param {integer} [flashRate] - Flash rate in Herz. Must be 0.5, 1 or 2 for a flash, or 0 for no flash. Default: 0
     * 
     */
    function setDisplayFlash(flashRate = 0) {
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
    
    /**
     *  Set the segment LED display to log extra debug info
     *
     *  @param {bool} [state] - Whether extra debugging is enabled (true) or not (false). Default: true
     *  
     */
    function setDebug(state = true) {
        if (typeof state != "bool") state = true;
        _debug = state;
    }

    /**
     *  Fill all the bars up to and including the specified bar with the specified color
     *
     *  @param {integer} barNumber - The highest bar number to be lit. 0-23
     *  @param {integer} ledColor  - The colour of the bar (0 [off], 1 [red], 2 [yellow], 3 [green])
     *  
     *  @returns {instance} The instance
    */
    function fill(barNumber, ledColor) {
        if (barNumber < 0 || barNumber > 23) {
            _logger.error("HT16K33Bargraph.fill() passed out of range (0-23) bar number");
            return null;
        }

        if (ledColor < HT16K33_BAR_CLASS_LED_OFF || ledColor > HT16K33_BAR_CLASS_LED_GREEN) {
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

        if (_debug) _logger.log("HT16K33Bargraph buffer bar filled to " + barNumber + " with colour " + ledColor);

        // Return the instance
        return this;
    }

    /**
     *  Set a specific bar to the specified color
     *
     *  @param {integer} barNumber - The bar number to be lit. 0-23
     *  @param {integer} ledColor  - The colour of the bar (0 [off], 1 [red], 2 [yellow], 3 [green])
     *  
     *  @returns {instance} The instance
    */
    function set(barNumber, ledColor) {
        if (barNumber < 0 || barNumber > 23) {
            _logger.error("HT16K33Bargraph.set() passed out of range (0-23) bar number");
            return null;
        }

        if (ledColor < HT16K33_BAR_CLASS_LED_OFF || ledColor > HT16K33_BAR_CLASS_LED_GREEN) {
            _logger.error("HT16K33Bargraph.set() passed out of range (0-2) LED colour");
            return null;
        }

        if (_barZeroByChip) barNumber = 23 - barNumber;
        _setBar(barNumber, ledColor);
        if (_debug) _logger.log("HT16K33Bargraph buffer bar " + barNumber + " set to colour " + ledColor);
        
        // Return the instance
        return this;
    }

    /**
     *  Clears the bargraph buffer
     *
     *  @returns {instance} The instance
    */
    function clear() {
        if (_debug) _logger.log("HT16K33Bargraph buffer cleared");
        _buffer = [0x0000, 0x0000, 0x0000];
        return this;
    }

    /**
     *  Writes the bargraph buffer out to the display itself
     *
    */
    function draw() {
        local dataString = HT16K33_BAR_CLASS_DISPLAY_ADDRESS;

        for (local i = 0 ; i < 3 ; i++) {
            // Each _buffer entry is a 16-bit value - convert to two 8-bit values to write
            dataString = dataString + (_buffer[i] & 0xFF).tochar() + (_buffer[i] >> 8).tochar();
        }

        _led.write(_ledAddress, dataString);
    }

    /**
     *  Turn the bargraph off
     * 
    */
    function powerDown() {
        if (_debug) _logger.log("Powering HT16K33Bargraph down");
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_DISPLAY_OFF);
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_SYSTEM_OFF);
    }

    /**
     *  Turn the bargraph on
     * 
    */
    function powerUp() {
        if (_debug) _logger.log("Powering HT16K33Bargraph up");
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_SYSTEM_ON);
        _led.write(_ledAddress, HT16K33_BAR_CLASS_REGISTER_DISPLAY_ON);
    }

    // ********** Private Functions DO NOT CALL DIRECTLY **********

    /**
     *  Sets a specific bar to the specified color. Called by 'set()' and 'fill()'
     * 
     *  @private
     *  
     *  @param {integer} barNumber - The chosen bar number (0 - 23)
     *  @param {integer} ledColor  - The LED color (0 [off], 1 [red], 2 [yellow], 3 [green])
     *
    */
    function _setBar(barNumber, ledColor) {
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

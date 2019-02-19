# HT16K33Bargraph 2.0.0 #

Hardware driver for [Adafruit Bi-Color (Red/Green) 24-Bar Bargraph with I&sup2;C Backpack](https://www.adafruit.com/products/1721) based on the Holtek HT16K33 controller. The LED communicates over any imp I&sup2;C bus.

## Class Usage ##

### Constructor: HT16K33Bargraph(*impI2cBus[, i2cAddress][, debug]*) ###

To instantiate an HT16K33Bargraph object, pass the I&sup2;C bus to which the display is connected and, optionally, its I&sup2;C address. If no address is passed, the default value, `0x70` will be used. Pass an alternative address if you have changed the display’s address using the solder pads on rear of the LED’s circuit board.

The passed imp I&sup2;C bus must be configured **before** the HT16K33Bargraph object is created.

Optionally, you can pass `true` into the *debug* parameter. This will cause debugging information to be posted to the device log. This is disabled by default.

#### Example ####

```squirrel
// Enabled debugging
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
bargraph <- HT16K33Bargraph(hardware.i2c89, 0x70, true);
```

### Constants ###

The class defines the following constants that you can use to specify bar colors (see *fill()* and *set()*):

- *HT16K33_BAR_CLASS_LED_OFF*
- *HT16K33_BAR_CLASS_LED_RED*
- *HT16K33_BAR_CLASS_LED_YELLOW*
- *HT16K33_BAR_CLASS_LED_AMBER*
- *HT16K33_BAR_CLASS_LED_GREEN*

**Note** From version 2.0.0, the constants have been renamed. This is a **breaking change**.

## Class Methods ##

### init(*brightness, barZeroByChip*) ###

Call *init()* to set the matrix’s initial settings. All the parameters are optional.

- *brightness* sets the LED intensity (duty cycle) to an integer value between 0 (dim) and 15 (maximum); the default is 15.
- *barZeroByChip* is a Boolean which allows you to indicate how you have oriented the board and therefore whether you want to count bars up from the end of the display nearest to the controller chip (`true`), or from the far end (`false`). The default value is `true`:

```squirrel
 ___________________________
| o  [CHIP] [BARGRAPH LEDs] |
 ---------------------------
bar number   0 . . . . . 23    barZeroByChip = true
bar number   23 . . . . . 0    barZeroByChip = false
```

#### Example ####

```squirrel
// Set matrix to max brightness and position the LED vertically
// with the controller chip at the top of the board, ie. 0 at
// the bottom of the board
bargraph.init(15, false);
```

This method returns *this* so you can chain other methods.

### fill(*barNumber, ledColor*) ###

This method sets all bars up to and including the specified bar number (0 - 23) to the specified *ledColor*. Which end the bars are filled from depends on the value passed into *init()* method’s *barZeroByChip* parameter.

This method returns *this* so you can chain other methods. Note that *fill()* updates the internal buffer but does not update the LED itself &mdash; you will need to call *draw()* to update the LED.

#### Example ####

```squirrel
function displayRain(data) {
    bargraph.clear()
            .fill(23 * data.rain.tofloat(), HT16K33_BAR_CLASS_LED_YELLOW)
            .draw();
}
```

### set(*barNumber, ledColor*) ###

This method sets the specified bar number (0 - 23) to the specified *ledColor*.

This method returns *this* so you can chain other methods. Note that *set()* updates the internal buffer but does not update the LED itself &mdash; you will need to call *draw()* to update the LED.

#### Example ####

```squirrel
// Mark peak signal (0 - 1.0) in red
bargraph.set((23 * signal), HT16K33_BAR_CLASS_LED_RED)
        .draw();
```

### clear() ###

Call *clear()* to clear the internal buffer. It does not update the LED itself &mdash; you will need to call *draw()* to update the LED.

This method returns *this* so you can chain other methods.

#### Example ####

```squirrel
// Clear the screen
bargraph.clear()
        .draw();
```

### draw() ###

Call *draw()* to apply the changes you have made to the internal buffer to the LED. See the above methods for examples of its use.

### setBrightness(*[brightness]*) ###

Call *setBrightness()* to set the matrix’s brightness (duty cycle) to a value between 0 (dim) and 15 (maximum). The value is optional; the matrix will be set to maximum brightness if no value is passed.

#### Example ####

```squirrel
// Set the display brightness to 50%
bargraph.setBrightness(8);
```

### setDisplayFlash(*flashRate*) ###

This method can be used to flash the display. The value passed into *flashRate* is the flash rate in Hertz. This value must be one of the following values, fixed by the HT16K33 controller: 0.5Hz, 1Hz or 2Hz. You can also pass in 0 to disable flashing, and this is the default value.

#### Example ####

```squirrel
// Blink the display every second
bargraph.setDisplayFlash(1);
```

### setDebug(*[state]*) ###

Call this method to enable (*state* is `true`) or disable (*state* is `false`) the logging of extra device debugging information. The default value is `true`.

### powerDown() ###

The display can be turned off by calling *powerDown()*.

### powerUp() ###

The display can be turned on by calling *powerup()*.

## Release Notes ##

- 2.0.0 &mdash; *Unreleased*
    - Revise constants as an enumeration **breaking change**
    - Add *setDisplayFlash()* method
    - Add *setDebug()* method
- 1.0.4 &mdash; *16 November 2018*
    - Minor code changes
- 1.0.3 &mdash; *May 2018*
    - Add support for [`seriallog.nut`](https://github.com/smittytone/generic/blob/master/seriallog.nut) to enable serial logging if the application makes use of it
        - **Note** Class will log to *server.log()* if *seriallog* is not present
- 1.0.2 &mdash; *October 2017*
    - Minor code change: rename constants to be class-specific
- 1.0.1 &mdash; *May 2017*
    - Streamline brightness control as per other HT16K33 libraries
- 1.0.0
    - Initial release

## License ##

The HT16K33Bargraph class is licensed under the [MIT License](./LICENSE).

Copyright &copy; 2015-19 by Tony Smith.

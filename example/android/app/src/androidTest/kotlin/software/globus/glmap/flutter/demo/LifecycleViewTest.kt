package software.globus.glmap.flutter.demo

import android.content.Intent
import android.graphics.Point
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiSelector
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LifecycleViewTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val device = UiDevice.getInstance(instrumentation)

    private fun launch(reset: Boolean = false) {
        val intent = requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or if (reset) Intent.FLAG_ACTIVITY_CLEAR_TASK else Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        context.startActivity(intent)
        val entry = checkNotNull(device.wait(Until.findObject(By.desc(
            java.util.regex.Pattern.compile("Read state|Lifecycle sample")
        )), 20000))
        if (entry.contentDescription == "Lifecycle sample") entry.click()
        checkNotNull(device.wait(Until.findObject(By.desc("Read state")), 15000))
        checkNotNull(device.wait(Until.findObject(By.res("native-state").descContains("zoom 5.00")), 20000))
    }

    private fun state(): String {
        // Let native single-tap confirmation finish, then await the asynchronous
        // capture/diagnostics round-trip and its Flutter semantics update.
        SystemClock.sleep(500)
        device.findObject(By.desc("Read state")).click()
        SystemClock.sleep(250)
        device.waitForIdle()
        val status = checkNotNull(device.wait(Until.findObject(By.res("native-state")), 5000))
        return status.contentDescription.also { android.util.Log.i("GLMapLifecycleTest", it) }
    }

    private fun capture(name: String) {
        // The Gradle runner uninstalls the target app after the test. Shell-owned
        // screenshots in Downloads survive that cleanup and can be pulled with adb.
        device.executeShellCommand("mkdir -p /sdcard/Download/glmap-flutter-demo")
        val output = device.executeShellCommand("screencap -p /sdcard/Download/glmap-flutter-demo/$name.png")
        assertTrue(output, output.isBlank())
    }

    @Test
    fun nativeGesturesKeyboardRotationAndResume() {
        device.setOrientationNatural()
        launch(reset = true)
        val canvas = checkNotNull(device.wait(Until.findObject(By.desc("GLMap canvas")), 10000))
        val bounds = canvas.visibleBounds
        val center = Point(bounds.centerX(), bounds.centerY())
        assertTrue(state().contains("zoom 5.00"))
        capture("A01-initial-map")

        device.click(center.x, center.y)
        assertTrue(state().contains("taps 1"))
        val beforePan = state()
        device.swipe(center.x, center.y, center.x + 180, center.y, 40)
        assertNotEquals(beforePan, state())
        // Keep both native fingers clear of Flutter controls and move far enough
        // for the SDK's pitch recognizer to release the pinch gesture.
        val beforePinch = Regex("zoom ([0-9.]+)").find(state())!!.groupValues[1].toDouble()
        device.findObject(By.desc("Toggle overlay")).click()
        val nativeView = device.findObject(UiSelector().description("GLMap canvas"))
        val gesture = Point(bounds.centerX(), bounds.top + bounds.height() * 2 / 3)
        assertTrue(nativeView.performTwoPointerGesture(
            Point(gesture.x - 80, gesture.y), Point(gesture.x + 80, gesture.y),
            Point(gesture.x - 230, gesture.y), Point(gesture.x + 230, gesture.y), 60))
        SystemClock.sleep(500)
        device.findObject(By.desc("Toggle overlay")).click()
        val afterPinch = Regex("zoom ([0-9.]+)").find(state())!!.groupValues[1].toDouble()
        assertTrue("Native pinch must increase zoom", afterPinch > beforePinch + 0.2)

        device.findObject(By.desc("Toggle overlay")).click()
        assertTrue(nativeView.performTwoPointerGesture(
            Point(gesture.x - 150, gesture.y), Point(gesture.x + 150, gesture.y),
            Point(gesture.x, gesture.y - 150), Point(gesture.x, gesture.y + 150), 60))
        SystemClock.sleep(1000)
        device.findObject(By.desc("Toggle overlay")).click()
        assertFalse(state().contains("angle 0.0"))
        capture("A03-after-native-gestures")

        val field = checkNotNull(device.findObject(By.clazz("android.widget.EditText")))
        field.click()
        device.waitForIdle()
        field.text = "Native keyboard"
        capture("A04-keyboard-overlay")
        device.pressBack()
        device.findObject(By.desc("Reset")).click()
        assertTrue(state().contains("zoom 5.00"))

        try {
            device.setOrientationLeft()
            device.waitForIdle()
            capture("A08-landscape")
            device.setOrientationNatural()
            for (cycle in 1..5) {
                device.pressHome()
                SystemClock.sleep(30000)
                launch()
                assertTrue(state().contains("zoom 5.00"))
                val current = device.findObject(By.desc("GLMap canvas")).visibleCenter
                device.click(current.x, current.y)
                assertTrue(state().contains("taps ${cycle + 1}"))
                capture("A07-resume-$cycle")
            }
        } finally {
            device.setOrientationNatural()
            device.unfreezeRotation()
        }
    }
}

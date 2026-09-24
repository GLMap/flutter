package software.globus.lab.glmap_lab_example

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
class StageAViewTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val device = UiDevice.getInstance(instrumentation)

    private fun launch() {
        val intent = requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        checkNotNull(device.wait(Until.findObject(By.desc("Read state")), 15000))
    }

    private fun state(): String {
        device.findObject(By.desc("Read state")).click()
        device.waitForIdle()
        val status = checkNotNull(device.wait(Until.findObject(By.res("native-state")), 5000))
        return status.contentDescription.also { android.util.Log.i("GLMapLabTest", it) }
    }

    private fun capture(name: String) {
        // The Gradle runner uninstalls the target app after the test. Shell-owned
        // screenshots in Downloads survive that cleanup and can be pulled with adb.
        device.executeShellCommand("mkdir -p /sdcard/Download/glmap-lab")
        val output = device.executeShellCommand("screencap -p /sdcard/Download/glmap-lab/$name.png")
        assertTrue(output, output.isBlank())
    }

    @Test
    fun nativeGesturesKeyboardRotationAndResume() {
        device.setOrientationNatural()
        launch()
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
        canvas.setGestureMargins(80, bounds.height() / 3, 80, bounds.height() / 3)
        canvas.pinchOpen(.7f)
        assertFalse(state().contains("zoom 5.00"))

        val nativeView = device.findObject(UiSelector().description("GLMap canvas"))
        assertTrue(nativeView.performTwoPointerGesture(
            Point(center.x - 100, center.y), Point(center.x + 100, center.y),
            Point(center.x, center.y - 100), Point(center.x, center.y + 100), 50))
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

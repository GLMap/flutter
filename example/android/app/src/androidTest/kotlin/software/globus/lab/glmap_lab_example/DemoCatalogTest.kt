package software.globus.lab.glmap_lab_example

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiSelector
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DemoCatalogTest {
    @Test fun nativeGesturesAndForegroundLocation() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val device = UiDevice.getInstance(instrumentation)
        context.startActivity(context.packageManager.getLaunchIntentForPackage(context.packageName)!!.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        fun open(title: String) {
            val field = checkNotNull(device.wait(Until.findObject(By.clazz("android.widget.EditText")), 20000))
            field.click()
            device.waitForIdle()
            field.text = title
            device.waitForIdle()
            assertTrue(device.findObject(UiSelector().descriptionStartsWith(title)).click())
            checkNotNull(device.wait(Until.findObject(By.desc("GLMap canvas")), 10000))
        }
        fun status(text: String) { assertNotNull(text, device.wait(Until.findObject(By.descContains(text)), 10000)) }
        open("Image Group")
        status("5 pins share one image")
        val canvas = device.findObject(By.desc("GLMap canvas")).visibleBounds
        val x = canvas.centerX(); val y = canvas.top + canvas.height() * 2 / 5
        device.swipe(x, y, x, y, 150)
        status("6 pins share one image")
        device.click(x, y)
        status("5 pins share one image")
        device.pressBack()
        open("User Location")
        device.findObject(By.desc("Use GPS")).click()
        device.wait(Until.findObject(By.res("com.android.permissioncontroller", "permission_allow_foreground_only_button")), 3000)?.click()
        status("42.43410, 19.26000")
        device.findObject(By.desc("Stop")).click()
        status("Location updates stopped")
    }
}

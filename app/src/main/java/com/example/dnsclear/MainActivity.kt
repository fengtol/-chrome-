package com.example.dnsclear

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.rosan.dhizuku.Dhizuku
import com.rosan.dhizuku.DhizukuRequestPermissionListener
import com.rosan.dhizuku.IDhizuku

class MainActivity : AppCompatActivity() {
    private val CHROME = "com.android.chrome"

    private val conn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            try {
                val dhizuku = IDhizuku.Stub.asInterface(service)
                val dpm = dhizuku.devicePolicyManager
                val admin = ComponentName(dhizuku.ownerPackageName, dhizuku.ownerComponentName)
                dpm.setApplicationRestrictions(admin, CHROME, Bundle())
                Toast.makeText(this@MainActivity,
                    "已清除 Chrome 策略，去 chrome://policy 重新加载确认", Toast.LENGTH_LONG).show()
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "执行失败: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
        override fun onServiceDisconnected(name: ComponentName?) {}
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Dhizuku.init(this)
        val btn = Button(this).apply {
            text = "清除 Chrome DoH 策略"
            setOnClickListener {
                if (Dhizuku.isPermissionGranted) {
                    Dhizuku.bindService(conn)
                } else {
                    Dhizuku.requestPermission(object : DhizukuRequestPermissionListener() {
                        override fun onRequestPermission(grantResult: Int) {
                            if (grantResult == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                Dhizuku.bindService(conn)
                            } else {
                                Toast.makeText(this@MainActivity, "未获得 Dhizuku 授权", Toast.LENGTH_SHORT).show()
                            }
                        }
                    })
                }
            }
        }
        setContentView(btn)
    }
}

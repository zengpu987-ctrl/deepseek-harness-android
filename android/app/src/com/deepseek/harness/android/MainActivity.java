package com.deepseek.harness.android;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.ContentResolver;
import android.content.pm.ActivityInfo;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.JavascriptInterface;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;

public final class MainActivity extends Activity implements SensorEventListener {
    private static final int FILE_CHOOSER_REQUEST = 1001;
    private static final int LOCAL_WORKSPACE_REQUEST = 1002;
    private static final String DEFAULT_API = "https://found-final-isolation-palm.trycloudflare.com";
    private static final String DEFAULT_VNC_BASE =
        "https://complimentary-distances-refresh-surprised.trycloudflare.com/vnc.html?autoconnect=true&reconnect=true&path=websockify";

    private WebView webView;
    private SharedPreferences prefs;
    private ValueCallback<Uri[]> filePathCallback;

    private SensorManager sensorManager;
    private Sensor rotationSensor;
    private boolean motionEnabled;
    private long lastMotionPush;

    private LinearLayout drawer;
    private ScrollView drawerScroll;
    private EditText urlInput;
    private EditText apiInput;
    private Switch motionSwitch;
    private boolean marketMode;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences("dsh", MODE_PRIVATE);
        motionEnabled = prefs.getBoolean("motion", true);

        FrameLayout root = new FrameLayout(this);
        webView = new WebView(this);
        root.addView(webView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        buildDrawer(root);

        final Button menuButton = new Button(this);
        menuButton.setText("\u2630");
        menuButton.setAllCaps(false);
        menuButton.setAlpha(0.9f);
        menuButton.setBackground(roundedBackground(Color.argb(220, 30, 34, 46), dp(12)));
        menuButton.setTextColor(Color.WHITE);
        menuButton.setTextSize(18);
        menuButton.setContentDescription("打开面板");
        FrameLayout.LayoutParams menuLp = new FrameLayout.LayoutParams(
                dp(46), dp(46), Gravity.TOP | Gravity.LEFT);
        menuLp.setMargins(dp(10), dp(10), 0, 0);
        root.addView(menuButton, menuLp);
        menuButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleDrawer();
            }
        });

        final ParticleSplashView splash = new ParticleSplashView(this);
        root.addView(splash, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        splash.start(new ParticleSplashView.OnFinishedListener() {
            @Override
            public void onFinished() {
                root.removeView(splash);
            }
        });

        setContentView(root);
        enterImmersiveMode();
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
        configureWebView();
        initSensors();

        String url = prefs.getString("url", "");
        String extraUrl = getIntent().getStringExtra("url");
        if (extraUrl != null && !extraUrl.isEmpty()) {
            url = extraUrl;
            prefs.edit().putString("url", url).apply();
        }
        if (url.isEmpty()) {
            openDrawer();
        } else {
            webView.loadUrl(url);
        }
    }

    private void configureWebView() {
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        settings.setBuiltInZoomControls(true);
        settings.setDisplayZoomControls(false);
        settings.setSupportZoom(true);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);

        webView.addJavascriptInterface(new AndroidBridge(), "AndroidBridge");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                view.loadUrl(url);
                return true;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                view.evaluateJavascript(MOTION_JS, null);
                view.evaluateJavascript(
                    "(function(){setTimeout(function(){"
                    + "var bs=document.querySelectorAll('button');"
                    + "for(var i=0;i<bs.length;i++){"
                    + "var t=(bs[i].innerText||'').trim();"
                    + "if(t==='Continue'||t==='继续'||t==='知道了'||t==='确定'){bs[i].click();break;}"
                    + "}},800);})();",
                    null);
                view.evaluateJavascript(MARKET_CLICK_JS, null);
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(
                    WebView webView,
                    ValueCallback<Uri[]> callback,
                    FileChooserParams params) {
                if (filePathCallback != null) {
                    filePathCallback.onReceiveValue(null);
                }
                filePathCallback = callback;
                Intent intent = params.createIntent();
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                try {
                    startActivityForResult(intent, FILE_CHOOSER_REQUEST);
                } catch (Exception ex) {
                    filePathCallback = null;
                    return false;
                }
                return true;
            }
        });
    }

    private void buildDrawer(FrameLayout root) {
        drawer = new LinearLayout(this);
        drawer.setOrientation(LinearLayout.VERTICAL);
        drawer.setPadding(dp(16), dp(12), dp(16), dp(12));

        drawerScroll = new ScrollView(this);
        drawerScroll.setBackgroundColor(Color.rgb(14, 17, 24));
        drawerScroll.setFillViewport(true);
        drawerScroll.addView(drawer, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT));

        FrameLayout.LayoutParams drawerLp = new FrameLayout.LayoutParams(
                dp(320), FrameLayout.LayoutParams.MATCH_PARENT, Gravity.LEFT);
        root.addView(drawerScroll, drawerLp);
        drawerScroll.setVisibility(View.GONE);

        TextView title = new TextView(this);
        title.setText("DeepSeek harness android");
        title.setTextColor(Color.WHITE);
        title.setTextSize(16);
        drawer.addView(title);

        addLabel(drawer, "连接设备");
        urlInput = new EditText(this);
        urlInput.setSingleLine(true);
        urlInput.setTextColor(Color.WHITE);
        urlInput.setHintTextColor(Color.GRAY);
        urlInput.setHint("http://ip:port/?token=...");
        urlInput.setText(prefs.getString("url", ""));
        drawer.addView(urlInput);

        Button connect = addButton(drawer, "连接");
        connect.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                connectToUrl(urlInput.getText().toString().trim());
            }
        });

        addLabel(drawer, "工作区");
        Button addWorkspace = addButton(drawer, "添加工作区");
        addWorkspace.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showWorkspaceOptions();
            }
        });

        addLabel(drawer, "远端控制");
        Button remoteControl = addButton(drawer, "控制已登录设备");
        remoteControl.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showDevices();
            }
        });

        Button graphicalControl = addButton(drawer, "图形远控电脑");
        graphicalControl.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                promptVncPassword();
            }
        });

        addLabel(drawer, "远程服务 / 插件市场");
        apiInput = new EditText(this);
        apiInput.setSingleLine(true);
        apiInput.setTextColor(Color.WHITE);
        apiInput.setHintTextColor(Color.GRAY);
        apiInput.setHint("https://...trycloudflare.com");
        apiInput.setText(prefs.getString("api", DEFAULT_API));
        drawer.addView(apiInput);

        Button market = addButton(drawer, "浏览插件市场");
        market.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                browseMarket();
            }
        });

        addLabel(drawer, "动效");
        LinearLayout motionRow = new LinearLayout(this);
        motionRow.setOrientation(LinearLayout.HORIZONTAL);
        motionRow.setGravity(Gravity.CENTER_VERTICAL);
        TextView motionLabel = new TextView(this);
        motionLabel.setText("陀螺仪视差");
        motionLabel.setTextColor(Color.WHITE);
        motionLabel.setLayoutParams(new LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        motionRow.addView(motionLabel);
        motionSwitch = new Switch(this);
        motionSwitch.setChecked(motionEnabled);
        motionSwitch.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                motionEnabled = isChecked;
                prefs.edit().putBoolean("motion", isChecked).apply();
                if (!isChecked) {
                    webView.evaluateJavascript(
                        "if(window.__dshMotionReset){window.__dshMotionReset()}",
                        null);
                }
            }
        });
        motionRow.addView(motionSwitch);
        drawer.addView(motionRow);

        Button refresh = addButton(drawer, "刷新界面");
        refresh.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                webView.reload();
            }
        });

        Button close = addButton(drawer, "关闭面板");
        close.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleDrawer();
            }
        });
    }

    private void addLabel(LinearLayout parent, String text) {
        TextView label = new TextView(this);
        label.setText(text);
        label.setTextColor(Color.argb(255, 150, 157, 176));
        label.setTextSize(12);
        label.setLetterSpacing(0.04f);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(16);
        lp.bottomMargin = dp(6);
        parent.addView(label, lp);
    }

    private Button addButton(LinearLayout parent, String text) {
        return addStyledButton(parent, text, Color.rgb(77, 107, 254), Color.WHITE);
    }

    private Button addStyledButton(LinearLayout parent, String text, int bgColor, int textColor) {
        Button button = new Button(this);
        button.setText(text);
        button.setAllCaps(false);
        button.setTextColor(textColor);
        button.setTextSize(14);
        button.setBackground(roundedBackground(bgColor, dp(8)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(44));
        lp.topMargin = dp(7);
        parent.addView(button, lp);
        return button;
    }

    private GradientDrawable roundedBackground(int color, float radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }

    private android.app.Dialog showRoundedDialog(String title, View content, boolean showClose) {
        android.app.Dialog dialog = new android.app.Dialog(this);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);

        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(20), dp(18), dp(20), dp(18));
        panel.setBackground(roundedBackground(Color.rgb(23, 27, 37), dp(18)));

        if (title != null) {
            TextView titleView = new TextView(this);
            titleView.setText(title);
            titleView.setTextColor(Color.WHITE);
            titleView.setTextSize(16);
            panel.addView(titleView);
            View spacer = new View(this);
            spacer.setLayoutParams(new LinearLayout.LayoutParams(1, dp(12)));
            panel.addView(spacer);
        }
        panel.addView(content);

        if (showClose) {
            Button close = addStyledButton(panel, "关闭", Color.argb(255, 42, 47, 58), Color.WHITE);
            close.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    dialog.dismiss();
                }
            });
        }

        dialog.setContentView(panel);
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawable(
                new android.graphics.drawable.ColorDrawable(Color.TRANSPARENT));
        }
        dialog.show();
        return dialog;
    }

    private void connectToUrl(String url) {
        if (url.isEmpty()) {
            Toast.makeText(this, "地址不能为空", Toast.LENGTH_SHORT).show();
            return;
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            url = "http://" + url;
        }
        prefs.edit().putString("url", url).apply();
        webView.loadUrl(url);
        toggleDrawer();
    }

    private void pickLocalWorkspace() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        try {
            startActivityForResult(intent, LOCAL_WORKSPACE_REQUEST);
        } catch (Exception ex) {
            Toast.makeText(this, "无法打开文件选择器", Toast.LENGTH_SHORT).show();
        }
    }

    private void showWorkspaceOptions() {
        final android.app.Dialog[] holder = new android.app.Dialog[1];
        LinearLayout opts = new LinearLayout(this);
        opts.setOrientation(LinearLayout.VERTICAL);

        Button local = addStyledButton(opts, "安卓手机内部文件", Color.rgb(77, 107, 254), Color.WHITE);
        local.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (holder[0] != null) {
                    holder[0].dismiss();
                }
                pickLocalWorkspace();
            }
        });

        Button remote = addStyledButton(opts, "远端设备文件", Color.rgb(77, 107, 254), Color.WHITE);
        remote.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (holder[0] != null) {
                    holder[0].dismiss();
                }
                openRemoteWorkspace();
            }
        });

        holder[0] = showRoundedDialog("选择工作区来源", opts, true);
    }

    private void openRemoteWorkspace() {
        webView.evaluateJavascript(
            "(function(){var els=document.querySelectorAll('button');"
            + "for(var i=0;i<els.length;i++){"
            + "var t=(els[i].innerText||'').trim();"
            + "if(t.indexOf('Choose workspace')>=0||t.indexOf('选择工作区')>=0||t.indexOf('工作区')>=0){els[i].click();return;}"
            + "}})();",
            null);
        Toast.makeText(MainActivity.this, "已打开远端工作区选择", Toast.LENGTH_SHORT).show();
    }

    private void showDevices() {
        final String api = prefs.getString("api", DEFAULT_API);
        runInBackground(new Runnable() {
            @Override
            public void run() {
                try {
                    final JSONArray arr = new JSONObject(RemoteApi.get(api + "/devices"))
                        .optJSONArray("devices");
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            showDeviceList(arr);
                        }
                    });
                } catch (Exception e) {
                    toastOnUi("获取设备列表失败");
                }
            }
        });
    }

    private void showDeviceList(JSONArray arr) {
        if (arr == null || arr.length() == 0) {
            toastOnUi("没有已登录设备");
            return;
        }
        final String[] labels = new String[arr.length()];
        for (int i = 0; i < arr.length(); i++) {
            JSONObject d = arr.optJSONObject(i);
            labels[i] = d.optString("name") + "  (" + d.optString("host") + ")";
        }

        final android.app.Dialog[] holder = new android.app.Dialog[1];
        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        for (final String label : labels) {
            Button b = addStyledButton(list, label, Color.rgb(77, 107, 254), Color.WHITE);
            b.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (holder[0] != null) {
                        holder[0].dismiss();
                    }
                    promptVncPassword();
                }
            });
        }
        holder[0] = showRoundedDialog("选择要控制的设备", list, true);
    }

    private void showRemoteConsole(final String deviceLabel) {
        final String api = prefs.getString("api", DEFAULT_API);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(12), dp(12), dp(12), dp(12));

        TextView title = new TextView(this);
        title.setText("控制：" + deviceLabel);
        title.setTextColor(Color.WHITE);
        title.setTextSize(14);
        box.addView(title);

        final EditText cmd = new EditText(this);
        cmd.setSingleLine(true);
        cmd.setTextColor(Color.WHITE);
        cmd.setHintTextColor(Color.GRAY);
        cmd.setHint("输入要在该设备执行的命令");
        box.addView(cmd);

        final TextView output = new TextView(this);
        output.setTextColor(Color.WHITE);
        output.setTextSize(12);
        output.setTypeface(android.graphics.Typeface.MONOSPACE);
        output.setText("(输出)");
        box.addView(output);

        Button run = new Button(this);
        run.setText("执行");
        run.setAllCaps(false);
        run.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                final String c = cmd.getText().toString().trim();
                if (c.isEmpty()) {
                    return;
                }
                runInBackground(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            final JSONObject o = new JSONObject(RemoteApi.exec(api, c));
                            final String text = o.optString("stdout", "")
                                + (o.optString("stderr", "").isEmpty() ? "" : "\n[stderr]\n" + o.optString("stderr", ""));
                            runOnUiThread(new Runnable() {
                                @Override
                                public void run() {
                                    output.setText(text.isEmpty() ? "(无输出)" : text);
                                }
                            });
                        } catch (Exception e) {
                            toastOnUi("执行失败");
                        }
                    }
                });
            }
        });
        box.addView(run);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(box);

        showRoundedDialog("远端设备控制台", scroll, true);
    }

    private void promptVncPassword() {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);

        final EditText password = new EditText(this);
        password.setSingleLine(true);
        password.setTextColor(Color.WHITE);
        password.setHintTextColor(Color.GRAY);
        password.setHint("输入 VNC 密码");
        password.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        password.setText(prefs.getString("vnc_password", ""));
        password.setSelection(password.getText().length());
        box.addView(password);

        final android.app.Dialog[] holder = new android.app.Dialog[1];
        Button connect = addStyledButton(box, "连接并操控电脑", Color.rgb(77, 107, 254), Color.WHITE);
        connect.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                final String pwd = password.getText().toString().trim();
                if (pwd.isEmpty()) {
                    password.setError("请输入密码");
                    return;
                }
                prefs.edit().putString("vnc_password", pwd).apply();
                String base = prefs.getString("vnc_base", DEFAULT_VNC_BASE);
                String url = base + "&password=" + Uri.encode(pwd);
                if (holder[0] != null) {
                    holder[0].dismiss();
                }
                Intent intent = new Intent(MainActivity.this, VncActivity.class);
                intent.putExtra("url", url);
                startActivity(intent);
            }
        });

        holder[0] = showRoundedDialog("远控电脑", box, true);
    }

    private void browseMarket() {
        final String api = apiInput.getText().toString().trim();
        if (api.isEmpty()) {
            Toast.makeText(this, "请先填写远程服务地址", Toast.LENGTH_SHORT).show();
            return;
        }
        prefs.edit().putString("api", api).apply();
        runInBackground(new Runnable() {
            @Override
            public void run() {
                try {
                    final JSONArray arr = new JSONObject(RemoteApi.get(api + "/plugins"))
                        .optJSONArray("plugins");
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            showMarket(arr);
                        }
                    });
                } catch (Exception e) {
                    toastOnUi("获取插件列表失败");
                }
            }
        });
    }

    private void showMarket(JSONArray arr) {
        ScrollView scroll = new ScrollView(this);
        final LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(dp(12), dp(12), dp(12), dp(12));
        scroll.addView(list);

        if (arr == null || arr.length() == 0) {
            TextView empty = new TextView(this);
            empty.setText("没有可用的插件");
            empty.setTextColor(Color.WHITE);
            list.addView(empty);
        } else {
            for (int i = 0; i < arr.length(); i++) {
                JSONObject p = arr.optJSONObject(i);
                if (p == null) {
                    continue;
                }
                final String name = p.optString("name");
                String version = p.optString("version");
                String desc = p.optString("description", "");

                TextView row = new TextView(this);
                row.setTextColor(Color.WHITE);
                row.setText(name + "  " + version + "\n" + desc);
                row.setTextSize(13);
                row.setPadding(0, dp(6), 0, dp(6));
                list.addView(row);

                Button install = new Button(this);
                install.setText("安装 " + name);
                install.setAllCaps(false);
                install.setOnClickListener(new View.OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        installPlugin(name);
                    }
                });
                list.addView(install);
            }
        }

        showRoundedDialog("插件市场", scroll, true);
    }

    private void installPlugin(final String pkg) {
        final String api = prefs.getString("api", DEFAULT_API);
        runInBackground(new Runnable() {
            @Override
            public void run() {
                try {
                    JSONObject o = new JSONObject(
                        RemoteApi.postJson(api + "/install", "{\"pkg\":\"" + pkg + "\"}"));
                    final boolean ok = o.optBoolean("ok");
                    final String out = o.optString("output", "");
                    toastOnUi(ok ? ("已安装 " + pkg) : ("安装失败 " + pkg + ": " + out));
                } catch (Exception e) {
                    toastOnUi("安装失败 " + pkg);
                }
            }
        });
    }

    private void uploadUris(final Uri[] uris) {
        final String api = prefs.getString("api", DEFAULT_API);
        runInBackground(new Runnable() {
            @Override
            public void run() {
                int ok = 0;
                for (Uri uri : uris) {
                    try {
                        RemoteApi.upload(api, readBytes(uri), fileName(uri));
                        ok++;
                    } catch (Exception ignored) {
                    }
                }
                final int done = ok;
                toastOnUi("已上传 " + done + " 个文件到电脑 ~/dsh-android-workspace");
            }
        });
    }

    private byte[] readBytes(Uri uri) throws Exception {
        InputStream in = getContentResolver().openInputStream(uri);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) != -1) {
            out.write(buf, 0, n);
        }
        in.close();
        return out.toByteArray();
    }

    private String fileName(Uri uri) {
        String name = null;
        Cursor cursor = getContentResolver().query(uri, null, null, null, null);
        if (cursor != null) {
            if (cursor.moveToFirst()) {
                int idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (idx >= 0) {
                    name = cursor.getString(idx);
                }
            }
            cursor.close();
        }
        return name == null ? "file" : name;
    }

    private void runInBackground(Runnable r) {
        new Thread(r).start();
    }

    private void toastOnUi(final String msg) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Toast.makeText(MainActivity.this, msg, Toast.LENGTH_LONG).show();
            }
        });
    }

    private void toggleDrawer() {
        if (drawerScroll.getVisibility() == View.VISIBLE) {
            drawerScroll.setVisibility(View.GONE);
        } else {
            openDrawer();
        }
    }

    private void openDrawer() {
        if (urlInput != null) {
            urlInput.setText(prefs.getString("url", ""));
        }
        drawerScroll.setVisibility(View.VISIBLE);
    }

    private void initSensors() {
        sensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        if (sensorManager != null) {
            rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
            if (rotationSensor == null) {
                rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
            }
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (sensorManager != null && rotationSensor != null) {
            sensorManager.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_GAME);
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
        }
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (!motionEnabled) {
            return;
        }
        long now = System.currentTimeMillis();
        if (now - lastMotionPush < 60) {
            return;
        }
        lastMotionPush = now;

        float pitch = 0f;
        float roll = 0f;
        if (event.sensor.getType() == Sensor.TYPE_ROTATION_VECTOR) {
            float[] matrix = new float[9];
            SensorManager.getRotationMatrixFromVector(matrix, event.values);
            float[] orientation = new float[3];
            SensorManager.getOrientation(matrix, orientation);
            pitch = (float) Math.toDegrees(orientation[1]);
            roll = (float) Math.toDegrees(orientation[2]);
        } else {
            // Accelerometer fallback: use x/y tilt from gravity.
            pitch = (float) Math.toDegrees(Math.atan2(-event.values[0], event.values[2]));
            roll = (float) Math.toDegrees(Math.atan2(event.values[1], event.values[2]));
        }
        webView.evaluateJavascript(
            "window.__dshMotion && window.__dshMotion(" + pitch + "," + roll + ")",
            null);
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }

    private void enterImmersiveMode() {
        if (Build.VERSION.SDK_INT >= 30) {
            Window window = getWindow();
            window.setDecorFitsSystemWindows(false);
            WindowInsetsController controller = window.getInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == FILE_CHOOSER_REQUEST) {
            if (filePathCallback == null) {
                return;
            }
            ValueCallback<Uri[]> callback = filePathCallback;
            filePathCallback = null;
            Uri[] results = collectUris(resultCode, data);
            callback.onReceiveValue(results);
            return;
        }
        if (requestCode == LOCAL_WORKSPACE_REQUEST) {
            Uri[] uris = collectUris(resultCode, data);
            if (uris == null || uris.length == 0) {
                return;
            }
            uploadUris(uris);
        }
    }

    private Uri[] collectUris(int resultCode, Intent data) {
        if (resultCode != Activity.RESULT_OK || data == null) {
            return null;
        }
        if (data.getClipData() != null) {
            int count = data.getClipData().getItemCount();
            Uri[] results = new Uri[count];
            for (int i = 0; i < count; i++) {
                results[i] = data.getClipData().getItemAt(i).getUri();
            }
            return results;
        }
        if (data.getData() != null) {
            return new Uri[] { data.getData() };
        }
        return null;
    }

    @Override
    public void onBackPressed() {
        if (marketMode) {
            marketMode = false;
            setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
            return;
        }
        if (drawerScroll.getVisibility() == View.VISIBLE) {
            drawerScroll.setVisibility(View.GONE);
            return;
        }
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    private final class AndroidBridge {
        @JavascriptInterface
        public void openMarket() {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    marketMode = true;
                    setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                }
            });
        }
    }

    private static final String MARKET_CLICK_JS =
        "(function(){"
        + "if(window.__dshMarketHookInstalled)return;"
        + "window.__dshMarketHookInstalled=true;"
        + "document.addEventListener('click',function(e){"
        + "var el=e.target;"
        + "while(el&&el!==document.body){"
        + "var t=(el.innerText||el.textContent||'').trim();"
        + "if(t==='插件市场'||t==='Plugin market'||t==='Marketplace'||t==='Market'){"
        + "try{window.AndroidBridge.openMarket();}catch(err){}"
        + "return;}"
        + "el=el.parentElement;}"
        + "},true);"
        + "})();";

    private static final String MOTION_JS =
        "(function(){"
        + "if(window.__dshMotionInstalled)return;"
        + "window.__dshMotionInstalled=true;"
        + "var tx=0,ty=0,cx=0,cy=0;"
        + "window.__dshMotion=function(pitch,roll){"
        + "cx=Math.max(-9,Math.min(9,pitch*1.15));"
        + "cy=Math.max(-9,Math.min(9,roll*1.15));};"
        + "window.__dshMotionReset=function(){cx=0;cy=0;};"
        + "function loop(){"
        + "tx+=(cx-tx)*0.12;ty+=(cy-ty)*0.12;"
        + "var b=document.body;"
        + "if(b){b.style.transform='perspective(850px) rotateX('+tx.toFixed(3)+'deg) rotateY('+ty.toFixed(3)+'deg) translateX('+(ty*6).toFixed(1)+'px) translateY('+(tx*6).toFixed(1)+'px)';b.style.willChange='transform';}"
        + "requestAnimationFrame(loop);}"
        + "requestAnimationFrame(loop);"
        + "})();";
}

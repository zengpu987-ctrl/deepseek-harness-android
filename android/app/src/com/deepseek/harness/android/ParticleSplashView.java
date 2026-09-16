package com.deepseek.harness.android;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.os.SystemClock;
import android.view.View;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

public final class ParticleSplashView extends View {
    public interface OnFinishedListener {
        void onFinished();
    }

    private static final int PARTICLE_COUNT = 460;
    private static final float CONVERGE_SECONDS = 2.8f;

    private final Random random = new Random();
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final List<float[]> targets = new ArrayList<>();
    private final Particle[] particles = new Particle[PARTICLE_COUNT];
    private final Bitmap whale;

    private long startTime = -1;
    private long fadeStart = -1;
    private boolean fading;
    private boolean finished;
    private OnFinishedListener listener;

    public ParticleSplashView(Context context) {
        super(context);
        Bitmap decoded = null;
        try {
            decoded = BitmapFactory.decodeStream(getResources().getAssets().open("whale.png"));
        } catch (Exception ignored) {
            decoded = null;
        }
        whale = decoded;
        for (int i = 0; i < PARTICLE_COUNT; i++) {
            particles[i] = new Particle();
        }
    }

    public void start(OnFinishedListener callback) {
        listener = callback;
        startTime = SystemClock.uptimeMillis();
        postInvalidateOnAnimation();
    }

    @Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        buildTargets(w, h);
        buildParticles(w, h);
    }

    private void buildTargets(int w, int h) {
        targets.clear();
        if (whale == null) {
            return;
        }
        float scale = Math.min(w, h) * 0.55f / Math.max(whale.getWidth(), whale.getHeight());
        int targetW = (int) (whale.getWidth() * scale);
        int targetH = (int) (whale.getHeight() * scale);
        int step = 3;
        int left = (w - targetW) / 2;
        int top = (h - targetH) / 2;
        for (int y = 0; y < whale.getHeight(); y += step) {
            for (int x = 0; x < whale.getWidth(); x += step) {
                int alpha = Color.alpha(whale.getPixel(x, y));
                if (alpha > 96) {
                    targets.add(new float[] {
                        left + x * scale,
                        top + y * scale,
                    });
                }
            }
        }
    }

    private void buildParticles(int w, int h) {
        if (targets.isEmpty()) {
            return;
        }
        for (Particle p : particles) {
            float[] target = targets.get(random.nextInt(targets.size()));
            p.ex = target[0];
            p.ey = target[1];
            float edge = random.nextInt(4);
            if (edge == 0) {
                p.sx = random.nextFloat() * w;
                p.sy = -20;
            } else if (edge == 1) {
                p.sx = random.nextFloat() * w;
                p.sy = h + 20;
            } else if (edge == 2) {
                p.sx = -20;
                p.sy = random.nextFloat() * h;
            } else {
                p.sx = w + 20;
                p.sy = random.nextFloat() * h;
            }
            p.delay = random.nextFloat() * 1.1f;
            p.duration = CONVERGE_SECONDS * (0.8f + random.nextFloat() * 0.6f);
            p.radius = 1.4f + random.nextFloat() * 2.2f;
            p.warm = random.nextFloat() > 0.3f;
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        canvas.drawColor(Color.rgb(5, 8, 18));
        if (startTime < 0) {
            return;
        }
        long now = SystemClock.uptimeMillis();
        float elapsed = (now - startTime) / 1000f;
        boolean allDone = true;

        for (Particle p : particles) {
            float t = (elapsed - p.delay) / p.duration;
            if (t < 0f) {
                t = 0f;
            }
            if (t < 1f) {
                allDone = false;
            }
            float eased = easeOutCubic(t);
            float x = p.sx + (p.ex - p.sx) * eased;
            float y = p.sy + (p.ey - p.sy) * eased;
            int alpha = (int) (150 + 105 * eased);
            int color = p.warm
                ? Color.argb(alpha, 150, 185, 255)
                : Color.argb(alpha, 77, 107, 254);
            paint.setColor(color);
            paint.setShadowLayer(p.radius * 3f, 0, 0, color);
            canvas.drawCircle(x, y, p.radius, paint);
        }
        paint.clearShadowLayer();

        if (allDone && !fading) {
            fading = true;
            fadeStart = now;
        }
        if (fading) {
            float fade = 1f - (now - fadeStart) / 650f;
            if (fade <= 0f) {
                if (!finished) {
                    finished = true;
                    post(new Runnable() {
                        @Override
                        public void run() {
                            if (listener != null) {
                                listener.onFinished();
                            }
                        }
                    });
                }
                return;
            }
            setAlpha(Math.max(0f, fade));
        }
        postInvalidateOnAnimation();
    }

    private static float easeOutCubic(float t) {
        if (t < 0f) {
            return 0f;
        }
        if (t > 1f) {
            return 1f;
        }
        float u = 1f - t;
        return 1f - u * u * u;
    }

    private static final class Particle {
        float sx;
        float sy;
        float ex;
        float ey;
        float delay;
        float duration;
        float radius;
        boolean warm;
    }
}

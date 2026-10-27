package com.example.rihan_jarvis

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.voice.VoiceInteractionSession
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.Executors

class MickeyVoiceSession(context: Context) : VoiceInteractionSession(context), TextToSpeech.OnInitListener {

    companion object {
        const val TAG = "MICKEY_SESSION"
        private const val BACKEND_URL = "http://127.0.0.1:3000/api/chat"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private var tts: TextToSpeech? = null
    private var isTtsReady = false

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false

    private lateinit var statusTextView: TextView
    private lateinit var responseTextView: TextView
    private lateinit var inputEditText: EditText
    private lateinit var micButton: Button

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "MickeyVoiceSession onCreate")

        // Enable display over lock screen and wake screen
        window?.window?.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        // Initialize TTS
        tts = TextToSpeech(context, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale("en", "IN")
            isTtsReady = true
            Log.d(TAG, "MickeyVoiceSession TTS initialized successfully")
        }
    }

    override fun onCreateContentView(): View {
        val density = context.resources.displayMetrics.density

        fun dp(value: Int): Int = (value * density).toInt()

        // Root container (semi-transparent dismiss backdrop)
        val root = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#77000000"))
            setOnClickListener { hide() }
        }

        // Floating Bottom Sheet Container
        val sheet = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            val params = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.BOTTOM
            }
            layoutParams = params
            setPadding(dp(20), dp(18), dp(20), dp(24))

            // Rounded top corners and futuristic dark cyan-bordered background
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#0d1322"))
                cornerRadii = floatArrayOf(
                    dp(24).toFloat(), dp(24).toFloat(),
                    dp(24).toFloat(), dp(24).toFloat(),
                    0f, 0f, 0f, 0f
                )
                setStroke(dp(1), Color.parseColor("#1de9b6"))
            }
            setOnClickListener { /* prevent dismissal when tapping sheet */ }
        }

        // Header bar with drag pill and title
        val pill = View(context).apply {
            val params = LinearLayout.LayoutParams(dp(40), dp(4)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(14)
            }
            layoutParams = params
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#33ffffff"))
                cornerRadius = dp(2).toFloat()
            }
        }
        sheet.addView(pill)

        // Title Row
        val titleRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(12)
            }
            layoutParams = params
        }

        val reactorOrb = View(context).apply {
            val params = LinearLayout.LayoutParams(dp(12), dp(12)).apply {
                rightMargin = dp(10)
            }
            layoutParams = params
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#00e676"))
            }
        }
        titleRow.addView(reactorOrb)

        val titleText = TextView(context).apply {
            text = "MICKEY DIGITAL ASSISTANT"
            setTextColor(Color.parseColor("#00e5ff"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.1f
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        titleRow.addView(titleText)

        val closeBtn = TextView(context).apply {
            text = "✕"
            setTextColor(Color.parseColor("#78909c"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setPadding(dp(8), dp(4), dp(8), dp(4))
            setOnClickListener { hide() }
        }
        titleRow.addView(closeBtn)
        sheet.addView(titleRow)

        // Status TextView
        statusTextView = TextView(context).apply {
            text = "Ready. Tap the mic or type your command, Sir."
            setTextColor(Color.parseColor("#b0bec5"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13.5f)
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
            layoutParams = params
        }
        sheet.addView(statusTextView)

        // Response Bubble TextView
        responseTextView = TextView(context).apply {
            visibility = View.GONE
            setTextColor(Color.parseColor("#f0f6fc"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#162033"))
                cornerRadius = dp(12).toFloat()
                setStroke(dp(1), Color.parseColor("#263238"))
            }
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(14)
            }
            layoutParams = params
        }
        sheet.addView(responseTextView)

        // Input Controls Row
        val inputRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Circular Mic Button
        micButton = Button(context).apply {
            text = "🎤"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            val btnParams = LinearLayout.LayoutParams(dp(44), dp(44)).apply {
                rightMargin = dp(8)
            }
            layoutParams = btnParams
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#00e676"))
            }
            setOnClickListener {
                if (isListening) stopListening() else startListening()
            }
        }
        inputRow.addView(micButton)

        // Text input field
        inputEditText = EditText(context).apply {
            hint = "Command Mickey..."
            setHintTextColor(Color.parseColor("#546e7a"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(dp(14), dp(10), dp(14), dp(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#080c15"))
                cornerRadius = dp(22).toFloat()
                setStroke(dp(1), Color.parseColor("#1c283f"))
            }
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setOnEditorActionListener { _, _, _ ->
                val cmd = text.toString().trim()
                if (cmd.isNotEmpty()) {
                    processCommand(cmd)
                    text.clear()
                }
                true
            }
        }
        inputRow.addView(inputEditText)

        // Send Button
        val sendBtn = Button(context).apply {
            text = "➔"
            setTextColor(Color.BLACK)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            val btnParams = LinearLayout.LayoutParams(dp(44), dp(44)).apply {
                leftMargin = dp(8)
            }
            layoutParams = btnParams
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#00e5ff"))
            }
            setOnClickListener {
                val cmd = inputEditText.text.toString().trim()
                if (cmd.isNotEmpty()) {
                    processCommand(cmd)
                    inputEditText.text.clear()
                }
            }
        }
        inputRow.addView(sendBtn)
        sheet.addView(inputRow)

        root.addView(sheet)
        return root
    }

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        Log.d(TAG, "MickeyVoiceSession onShow summoned (showFlags=$showFlags)")
        responseTextView.visibility = View.GONE
        statusTextView.text = "Listening for your command, Sir..."
        startListening()
    }

    override fun onHide() {
        super.onHide()
        Log.d(TAG, "MickeyVoiceSession onHide")
        stopListening()
        tts?.stop()
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        tts?.shutdown()
        executor.shutdown()
        super.onDestroy()
    }

    private fun startListening() {
        if (isListening) return

        mainHandler.post {
            try {
                if (speechRecognizer == null) {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context)
                    speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {
                            statusTextView.text = "Listening to your voice, Sir..."
                        }

                        override fun onBeginningOfSpeech() {}
                        override fun onRmsChanged(rmsdB: Float) {}
                        override fun onBufferReceived(buffer: ByteArray?) {}
                        override fun onEndOfSpeech() {
                            statusTextView.text = "Processing speech..."
                        }

                        override fun onError(error: Int) {
                            Log.w(TAG, "SpeechRecognizer error: $error")
                            isListening = false
                            micButton.background = GradientDrawable().apply {
                                shape = GradientDrawable.OVAL
                                setColor(Color.parseColor("#00e676"))
                            }
                        }

                        override fun onResults(results: Bundle?) {
                            isListening = false
                            micButton.background = GradientDrawable().apply {
                                shape = GradientDrawable.OVAL
                                setColor(Color.parseColor("#00e676"))
                            }
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                val spoken = matches[0].trim()
                                Log.d(TAG, "Speech recognized: \"$spoken\"")
                                processCommand(spoken)
                            }
                        }

                        override fun onPartialResults(partialResults: Bundle?) {
                            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!matches.isNullOrEmpty()) {
                                statusTextView.text = matches[0]
                            }
                        }

                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })
                }

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                }

                speechRecognizer?.startListening(intent)
                isListening = true
                micButton.background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#ff1744")) // Red when recording
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start speech recognition: ${e.message}", e)
                isListening = false
            }
        }
    }

    private fun stopListening() {
        if (!isListening) return
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                isListening = false
                micButton.background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor("#00e676"))
                }
            } catch (e: Exception) {
                Log.w(TAG, "stopListening error: ${e.message}")
            }
        }
    }

    private fun processCommand(rawCommand: String) {
        // Strip wake word prefix if user said "Hey Mickey, open YouTube"
        val cleanCommand = rawCommand.replace(
            Regex("^(?:(?:hey|suno|hello|hi)\\s+)?(?:mick(?:ey|y)|jarvis)[,\\s:]*", RegexOption.IGNORE_CASE),
            ""
        ).trim()
        val command = if (cleanCommand.isNotEmpty()) cleanCommand else rawCommand

        statusTextView.text = "\"$command\""
        responseTextView.visibility = View.VISIBLE
        responseTextView.text = "Thinking..."

        executor.execute {
            try {
                Log.d(TAG, "Sending request to backend: $command")
                val url = URL(BACKEND_URL)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 6000
                conn.readTimeout = 8000
                conn.doOutput = true

                val payload = JSONObject().apply {
                    put("message", command)
                }

                OutputStreamWriter(conn.outputStream).use { writer ->
                    writer.write(payload.toString())
                    writer.flush()
                }

                val responseCode = conn.responseCode
                Log.d(TAG, "Backend response code: $responseCode")

                val responseStr = if (responseCode in 200..299) {
                    BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText() }
                } else {
                    BufferedReader(InputStreamReader(conn.errorStream)).use { it.readText() }
                }

                val json = JSONObject(responseStr)
                val reply = json.optString("reply", "Understood, Sir.")
                val isAction = json.optString("type") == "action"

                mainHandler.post {
                    responseTextView.text = reply

                    // Speak aloud via TTS
                    if (isTtsReady) {
                        tts?.speak(reply, TextToSpeech.QUEUE_FLUSH, null, "mickey_session_tts")
                    }

                    // Auto-execute structured action if present
                    if (isAction) {
                        executeAssistantAction(json)
                    }

                    // Auto-dismiss session after action or speech completes
                    mainHandler.postDelayed({
                        hide()
                    }, if (isAction) 1500 else 4000)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing assistant command: ${e.message}", e)
                mainHandler.post {
                    responseTextView.text = "I encountered an issue connecting to the core, Sir."
                }
            }
        }
    }

    private fun executeAssistantAction(actionJson: JSONObject) {
        val action = actionJson.optString("action")
        val app = actionJson.optString("app")
        val query = actionJson.optString("query")
        val phoneNumber = actionJson.optString("phoneNumber")
        val message = actionJson.optString("message")

        Log.d(TAG, "Executing assistant action: $action (app=$app, query=$query, phone=$phoneNumber)")

        try {
            when (action) {
                "open_app" -> {
                    when (app.lowercase()) {
                        "youtube" -> launchPackage("com.google.android.youtube")
                        "chrome" -> launchPackage("com.android.chrome")
                        "maps" -> launchPackage("com.google.android.apps.maps")
                        "settings" -> {
                            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                        }
                    }
                }
                "google_search" -> {
                    val encoded = Uri.encode(query)
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=$encoded")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                }
                "youtube_search" -> {
                    val encoded = Uri.encode(query)
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=$encoded")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                }
                "make_call" -> {
                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phoneNumber")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                }
                "send_sms" -> {
                    val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$phoneNumber")).apply {
                        putExtra("sms_body", message)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                }
                "open_whatsapp" -> {
                    val encoded = Uri.encode(message)
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$phoneNumber?text=$encoded")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch intent for action $action: ${e.message}", e)
        }
    }

    private fun launchPackage(pkg: String) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(pkg)
        if (launchIntent != null) {
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(launchIntent)
        }
    }
}

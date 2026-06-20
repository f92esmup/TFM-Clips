//+------------------------------------------------------------------+
//|                                                        clips.mqh |
//|                                  Copyright 2026, Pedro Escudero. |
//+------------------------------------------------------------------+
#property strict

#import "Clipswrapper.dll"
long  InitClips();
int   ClipsBuild(long handle, const string construct);
int   ClipsEval(long handle, const string command);
void  ClipsGetStr(long handle, const string expression, string &buffer, int bufferSize);
void  ClipsGetOutput(long handle, string &buffer, int bufferSize);
void  DeinitClips(long handle);
#import

//+------------------------------------------------------------------+
//| Motor de Inferencia CLIPS para MQL5                              |
//+------------------------------------------------------------------+
class CClipsEngine
  {
private:
   long              m_handle;        // Puntero a la instancia ClipsInstance en C++
   int               m_buffer_size;
   string            m_last_error;

   // Centraliza la extracción de logs del router
   void              CaptureError(string context)
     {
      string error_msg = GetLog();
      if(StringLen(error_msg) > 0)
        {
         m_last_error = error_msg;
         PrintFormat("CLIPS [%s]: %s", context, m_last_error);
        }
     }

public:
                     CClipsEngine(int buffer_size = 4096) : m_buffer_size(buffer_size)
     {
      m_handle = InitClips();
      m_last_error = "";
     }

                    ~CClipsEngine()
     {
      if(m_handle != 0)
        {
         DeinitClips(m_handle);
        }
     }

   // --- ABSTRACCIONES DE COMANDOS TÍPICOS ---

   // Limpia hechos y activa valores iniciales (deffacts)
   void              Reset() { Eval("(reset)"); }

   // Inicia la ejecución de las reglas en la agenda
   void              Run()   { Eval("(run)"); }

   // Elimina todos los hechos y constructos (reglas, plantillas)
   void              Clear() { Eval("(clear)"); }

   // Carga un archivo .clp externo
   bool              Load(string file_path)
     {
      // CLIPS requiere barras "/" o "\\". Ajustamos la ruta de Windows automáticamente.
      StringReplace(file_path, "\\", "/");
      string cmd = StringFormat("(load \"%s\")", file_path);

      // Load se ejecuta vía Eval y retorna -1 si falla la apertura del archivo
      if(Eval(cmd) == -1)
        {
         CaptureError("Load File Error");
         return false;
        }
      return true;
     }

   // Inserta un hecho de forma rápida
   void              Assert(string fact)
     {
      Eval(StringFormat("(assert %s)", fact));
     }

   // --- MÉTODOS NATIVOS DEL WRAPPER ---

   // Define constructos: defrule, deftemplate, deffunction
   bool              Build(const string construct)
     {
      if(m_handle == 0)
         return false;
      if(ClipsBuild(m_handle, construct) <= 0)
        {
         CaptureError("Syntax Error");
         return false;
        }
      return true;
     }

   // Ejecuta cualquier comando o función de CLIPS
   int               Eval(const string command)
     {
      if(m_handle == 0)
         return -1;
      int res = ClipsEval(m_handle, command);
      if(res != 0)
         CaptureError("Execution Error");
      return res;
     }

   // Evalúa una expresión y extrae el resultado como string
   string            GetStr(const string expression)
     {
      if(m_handle == 0)
         return "";
      string res;
      StringInit(res, m_buffer_size);
      ClipsGetStr(m_handle, expression, res, m_buffer_size);
      if(res == "EVAL_ERROR")
        {
         CaptureError("Evaluation Error");
         return "";
        }
      return res;
     }

   string            GetLog()
     {
      if(m_handle == 0)
         return "Invalid Handle";
      string buffer;
      StringInit(buffer, m_buffer_size);
      ClipsGetOutput(m_handle, buffer, m_buffer_size);
      return buffer;
     }

   string            GetLastError() const { return m_last_error; }
   bool              IsReady()      const { return m_handle != 0; }
  };
//+------------------------------------------------------------------+

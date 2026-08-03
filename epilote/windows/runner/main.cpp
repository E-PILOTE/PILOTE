#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Taille de repli, en pixels LOGIQUES : Win32Window la multiplie par le
  // facteur d'échelle de l'écran. Sur un poste à 125 %, 1280x720 devient
  // 1600x900 — plus large que l'écran 1366x768 courant dans les
  // établissements. On reste donc modeste ici, et on maximise juste après.
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1100, 700);
  if (!window.Create(L"E-PILOTE CONGO", origin, size)) {
    return EXIT_FAILURE;
  }
  // L'application est dense — barre latérale, tableaux, tableaux de bord. Elle
  // s'ouvre maximisée pour prendre l'écran tel qu'il est, quelle que soit sa
  // définition. L'agent garde la main : Windows retient ensuite son choix.
  ::ShowWindow(window.GetHandle(), SW_MAXIMIZE);
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}

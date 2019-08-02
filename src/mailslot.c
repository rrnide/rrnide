// gcc [-m32] mailslot.c -shared -s -O -o mailslot.dll
// x86 ver --> rgss
// x64 ver --> ruby
#include <windows.h>
#define API extern __declspec(dllexport)

/**
 * Create a Mailslot server for read.
 * @param  szName  ascii slot name,
 *                 should be in the form of "\\\\.\\mailslot\\abc".
 * @return         the handle of the server,
 *                 it returns INVALID_HANDLE_VALUE (-1) if failed.
 */
API HANDLE Create(LPSTR szName) {
    return CreateMailslot(szName, 0, MAILSLOT_WAIT_FOREVER, NULL);
}

/**
 * Open an existing Mailslot server for write.
 * @param  szName  ascii slot name,
 *                 should be in the form of "\\\\.\\mailslot\\abc".
 * @return         the handle of the server,
 *                 it returns INVALID_HANDLE_VALUE (-1) if failed.
 */
API HANDLE Open(LPSTR szName) {
    return CreateFile(szName, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
}

/**
 * Read message from Mailslot server.
 * @param  hServer  the handle to that server.
 * @param  lpBuffer the buffer to receive message.
 * @param  nRead    max bytes to read.
 * @return          if nRead is 0, it returns required lpBuffer size,
 *                  otherwise it writes message to lpBuffer and
 *                  returns the bytes have read,
 *                  anyway, it returns 0 if failed.
 */
API DWORD Read(HANDLE hServer, LPVOID lpBuffer, DWORD nRead) {
    DWORD cbMessage, cMessage, cbRead;
    BOOL fResult = GetMailslotInfo(hServer, NULL, &cbMessage, &cMessage, NULL);
    if (!fResult || cbMessage == MAILSLOT_NO_MESSAGE) {
        return 0;
    }
    if (nRead == 0) {
        return cbMessage;
    }
    HANDLE hEvent = CreateEvent(NULL, FALSE, FALSE, NULL);
    OVERLAPPED ov = { .hEvent = hEvent };
    fResult = ReadFile(hServer, lpBuffer, cbMessage, &cbRead, &ov);
    if (!fResult) {
        CloseHandle(hEvent);
        return 0;
    }
    CloseHandle(hEvent);
    return cbRead;
}

/**
 * Write message to Mailslot server.
 * @param  hServer  the handle to that server.
 * @param  lpBuffer the message buffer.
 * @param  nWrite   max bytes to write.
 * @return          the bytes have written,
 *                  it returns 0 if failed.
 */
API DWORD Write(HANDLE hServer, LPVOID lpBuffer, DWORD nWrite) {
    DWORD cbWritten;
    BOOL fResult = WriteFile(hServer, lpBuffer, nWrite, &cbWritten, NULL);
    if (!fResult) {
        return 0;
    }
    return cbWritten;
}

/**
 * Close a handle to Mailslot server.
 * @param  hServer the handle to that server.
 * @return         true if success, otherwise false.
 */
API BOOL Close(HANDLE hServer) {
    return CloseHandle(hServer);
}

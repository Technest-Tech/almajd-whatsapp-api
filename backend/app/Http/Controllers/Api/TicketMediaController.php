<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ticket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class TicketMediaController extends Controller
{
    /**
     * Download or stream media for a ticket.
     * GET /api/media/tickets/{ticket}/{filename}
     */
    public function download(int $ticket, string $filename)
    {
        $path = 'tickets/' . $ticket . '/' . $filename;
        
        if (!Storage::disk('public')->exists($path)) {
            abort(404);
        }

        $mime = Storage::disk('public')->mimeType($path);
        
        // Force audio/mp4 for m4a files so Twilio WhatsApp accepts it
        if (str_ends_with(strtolower($filename), '.m4a') || $mime === 'audio/x-m4a') {
            $mime = 'audio/mp4';
        }

        return response()->file(Storage::disk('public')->path($path), [
            'Content-Type' => $mime,
            'Content-Disposition' => 'inline; filename="' . $filename . '"',
        ]);
    }

    /**
     * Upload media (image, audio, document) for a specific ticket.
     * POST /api/tickets/{ticket}/upload
     */
    public function upload(Request $request, int $ticket): JsonResponse
    {
        $request->validate([
            'file' => 'required|file|max:20480', // limit to 20MB
        ]);

        $ticketModel = Ticket::findOrFail($ticket);
        $file = $request->file('file');
        
        // Generate an unguessable filename
        $extension = $file->getClientOriginalExtension() ?: 'bin';
        $filename = Str::ulid() . '.' . $extension;
        
        // Store in public visibility disk under the specific ticket folder
        $path = $file->storeAs('tickets/' . $ticketModel->id, $filename, 'public');
        
        if (!$path) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Failed to store the uploaded file.',
            ], 500);
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'File uploaded successfully',
            'data'    => [
                'media_url' => route('ticket.media.download', ['ticket' => $ticketModel->id, 'filename' => $filename]),
                'mime_type' => $file->getMimeType(),
                'size'      => $file->getSize(),
            ]
        ], 201);
    }
}

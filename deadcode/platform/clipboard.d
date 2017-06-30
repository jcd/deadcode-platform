module deadcode.platform.clipboard;

import std.conv;
import std.string;

import derelict.sdl2.functions;

interface ISystemClipboard
{    
    @property
    {
        bool hasText() const;
        string text() const;
        void text(string t);
    }
}

class SDLClipboard : ISystemClipboard
{    
    @property
    {
        bool hasText() const
        {
            return SDL_HasClipboardText() != 0;
        }

        string text() const
        {
            return SDL_GetClipboardText().to!string();
        }

        void text(string t)
        {
            SDL_SetClipboardText(t.toStringz());
        }
    }
}
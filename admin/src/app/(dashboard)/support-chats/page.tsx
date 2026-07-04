'use client';

import { useState, useRef, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { adminApi } from '@/lib/api';
import { Send, MessageSquare } from 'lucide-react';
import toast from 'react-hot-toast';

interface Conversation {
  userId: string;
  name: string;
  mobile: string;
  profileImage?: string;
  lastMessage: string;
  lastMessageAt: string;
  lastSender: string;
  unread: number;
}

interface Message {
  _id: string;
  sender: 'user' | 'admin';
  text: string;
  createdAt: string;
}

function timeAgo(iso?: string) {
  if (!iso) return '';
  const d = new Date(iso);
  const mins = Math.floor((Date.now() - d.getTime()) / 60000);
  if (mins < 1) return 'now';
  if (mins < 60) return `${mins}m`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h`;
  return d.toLocaleDateString('en-IN');
}

export default function SupportChatsPage() {
  const qc = useQueryClient();
  const [selected, setSelected] = useState<Conversation | null>(null);

  const { data: chatsRaw } = useQuery({
    queryKey: ['support-chats'],
    queryFn: () => adminApi.getSupportChats(),
    refetchInterval: 8000,
  });
  const conversations: Conversation[] = (chatsRaw as any)?.data || [];

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <MessageSquare className="w-6 h-6 text-orange-500" />
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Support Chats</h1>
          <p className="text-sm text-gray-500">Chat with users — each user has their own conversation</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 h-[calc(100vh-220px)]">
        {/* Conversation list */}
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-y-auto">
          {conversations.length === 0 ? (
            <p className="p-6 text-sm text-gray-400 text-center">No support conversations yet.</p>
          ) : (
            conversations.map((c) => (
              <button
                key={c.userId}
                onClick={() => setSelected(c)}
                className={`w-full flex items-center gap-3 px-4 py-3 border-b border-gray-100 dark:border-gray-800 text-left hover:bg-gray-50 dark:hover:bg-gray-800 ${
                  selected?.userId === c.userId ? 'bg-orange-50 dark:bg-orange-900/20' : ''
                }`}
              >
                <div className="w-10 h-10 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-semibold shrink-0">
                  {c.name?.[0]?.toUpperCase()}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium text-sm truncate">{c.name}</span>
                    <span className="text-[10px] text-gray-400 shrink-0">{timeAgo(c.lastMessageAt)}</span>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs text-gray-500 truncate">
                      {c.lastSender === 'admin' ? 'You: ' : ''}{c.lastMessage}
                    </span>
                    {c.unread > 0 && (
                      <span className="bg-orange-500 text-white text-[10px] font-bold rounded-full px-1.5 min-w-[18px] text-center shrink-0">{c.unread}</span>
                    )}
                  </div>
                </div>
              </button>
            ))
          )}
        </div>

        {/* Conversation panel */}
        <div className="lg:col-span-2 bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
          {selected ? (
            <ConversationPanel
              conversation={selected}
              onReplied={() => qc.invalidateQueries({ queryKey: ['support-chats'] })}
            />
          ) : (
            <div className="h-full flex items-center justify-center text-gray-400 text-sm">
              Select a conversation to reply
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function ConversationPanel({ conversation, onReplied }: { conversation: Conversation; onReplied: () => void }) {
  const qc = useQueryClient();
  const [text, setText] = useState('');
  const bottomRef = useRef<HTMLDivElement>(null);

  const { data: convRaw } = useQuery({
    queryKey: ['support-conv', conversation.userId],
    queryFn: () => adminApi.getSupportConversation(conversation.userId),
    refetchInterval: 6000,
  });
  const messages: Message[] = (convRaw as any)?.data?.messages || [];

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages.length]);

  const replyMutation = useMutation({
    mutationFn: (t: string) => adminApi.replySupport(conversation.userId, t),
    onSuccess: () => {
      setText('');
      qc.invalidateQueries({ queryKey: ['support-conv', conversation.userId] });
      onReplied();
    },
    onError: (e: any) => toast.error(e?.message || 'Could not send'),
  });

  const send = () => {
    const t = text.trim();
    if (t) replyMutation.mutate(t);
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-200 dark:border-gray-700">
        <div className="w-9 h-9 rounded-full bg-orange-100 flex items-center justify-center text-orange-600 font-semibold">
          {conversation.name?.[0]?.toUpperCase()}
        </div>
        <div>
          <p className="font-semibold text-sm">{conversation.name}</p>
          <p className="text-xs text-gray-500 font-mono">{conversation.mobile}</p>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-2 bg-gray-50 dark:bg-gray-950/30">
        {messages.map((m) => {
          const isAdmin = m.sender === 'admin';
          return (
            <div key={m._id} className={`flex ${isAdmin ? 'justify-end' : 'justify-start'}`}>
              <div className={`max-w-[70%] rounded-2xl px-3 py-2 text-sm ${isAdmin ? 'bg-orange-500 text-white rounded-br-sm' : 'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-bl-sm'}`}>
                <p>{m.text}</p>
                <p className={`text-[10px] mt-0.5 ${isAdmin ? 'text-white/70' : 'text-gray-400'}`}>
                  {new Date(m.createdAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="flex items-center gap-2 p-3 border-t border-gray-200 dark:border-gray-700">
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') send(); }}
          placeholder="Type a reply…"
          className="flex-1 border border-gray-200 dark:border-gray-700 dark:bg-gray-800 rounded-full px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-500"
        />
        <button
          onClick={send}
          disabled={replyMutation.isPending || !text.trim()}
          className="w-10 h-10 rounded-full bg-orange-500 text-white flex items-center justify-center disabled:opacity-50"
        >
          <Send className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}

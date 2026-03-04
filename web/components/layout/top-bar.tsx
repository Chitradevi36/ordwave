"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { Bell, Search, User, LogOut } from "lucide-react";

export interface TopBarProps {
  title?: string;
}

export function TopBar({ title }: TopBarProps) {
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [user, setUser] = useState<any>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const router = useRouter();

  useEffect(() => {
    // Load user from localStorage
    const userData = localStorage.getItem("user");
    if (userData) {
      setUser(JSON.parse(userData));
    }

    // Close menu when clicking outside
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setShowUserMenu(false);
      }
    }

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleLogout = async () => {
    try {
      const token = localStorage.getItem("auth_token");
      
      if (token) {
        await fetch("http://localhost:3001/api/v1/auth/logout", {
          method: "DELETE",
          headers: {
            "Authorization": `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        });
      }
    } catch (error) {
      console.error("Logout error:", error);
    } finally {
      // Clear local storage and redirect
      localStorage.removeItem("auth_token");
      localStorage.removeItem("user");
      localStorage.removeItem("organization_id");
      router.push("/login");
    }
  };

  return (
    <header className="flex h-16 items-center justify-between border-b border-border bg-background px-6">
      {title && (
        <h1 className="text-lg font-semibold text-text-primary">{title}</h1>
      )}
      <div className="ml-auto flex items-center gap-3">
        <button className="flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors">
          <Search className="h-4 w-4 text-text-secondary" />
        </button>
        <button className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors">
          <Bell className="h-4 w-4 text-text-secondary" />
          <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-danger" />
        </button>
        
        {/* User Menu */}
        <div className="relative" ref={menuRef}>
          <button 
            onClick={() => setShowUserMenu(!showUserMenu)}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-white hover:bg-primary-700 transition-colors"
          >
            <User className="h-4 w-4" />
          </button>
          
          {showUserMenu && (
            <div className="absolute right-0 mt-2 w-64 rounded-lg border border-border bg-background shadow-lg z-50">
              {/* User Info */}
              <div className="px-4 py-3 border-b border-border">
                <p className="text-sm font-medium text-text-primary">
                  {user?.first_name} {user?.last_name}
                </p>
                <p className="text-xs text-text-secondary mt-0.5">
                  {user?.email}
                </p>
              </div>
              
              {/* Menu Items */}
              <div className="py-1">
                <button
                  onClick={handleLogout}
                  className="w-full flex items-center gap-3 px-4 py-2 text-sm text-danger hover:bg-background-subtle transition-colors"
                >
                  <LogOut className="h-4 w-4" />
                  Logout
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

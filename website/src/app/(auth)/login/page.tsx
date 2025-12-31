"use client";

import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

const formSchema = z.object({
  email: z.string().email({
    message: "Please enter a valid email address.",
  }),
  password: z.string().min(1, {
    message: "Password is required.",
  }),
});

export default function LoginPage() {
  const router = useRouter();
  const [canResendVerification, setCanResendVerification] = useState(false);
  const [resendEmail, setResendEmail] = useState<string>("");
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  });

  async function onSubmit(values: z.infer<typeof formSchema>) {
    try {
      setCanResendVerification(false);
      setResendEmail("");

      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
      const response = await fetch(`${apiUrl}/auth/login`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          Email: values.email,
          Password: values.password,
        }),
      });

      if (!response.ok) {
        let err: any = null;
        try {
          err = await response.json();
        } catch {
          // ignore
        }

        const text = err ? JSON.stringify(err) : await response.text();
        console.error("Login failed response:", text);

        if (err?.code === "email_not_verified") {
          setCanResendVerification(true);
          setResendEmail(values.email);
          throw new Error("Email not verified");
        }

        throw new Error("Invalid credentials");
      }

      const data = await response.json();
      // Store token and user in localStorage
      // API returns PascalCase properties
      localStorage.setItem("token", data.Token || data.token);
      localStorage.setItem("user", JSON.stringify(data.User || data.user));
      
      toast.success("Logged in successfully");
      router.push("/dashboard");
    } catch (error: any) {
      console.error("Login error:", error);
      const msg = typeof error?.message === "string" ? error.message : "";
      toast.error(
        msg === "Email not verified"
          ? "Email not verified. Check your inbox or resend verification."
          : "Login failed. Please check your credentials."
      );
    }
  }

  async function resendVerification() {
    if (!resendEmail) return;
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.displaydeck.co.za";
      const res = await fetch(`${apiUrl}/auth/resend-verification`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ Email: resendEmail }),
      });
      if (!res.ok) {
        const text = await res.text();
        console.error("Resend verification failed:", text);
        throw new Error("Failed");
      }
      toast.success("If the account exists, a verification email has been sent.");
    } catch (e) {
      console.error(e);
      toast.error("Could not resend verification email.");
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle className="text-2xl">Login</CardTitle>
          <CardDescription>
            Enter your email below to login to your account.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="email"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Email</FormLabel>
                    <FormControl>
                      <Input placeholder="m@example.com" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="password"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Password</FormLabel>
                    <FormControl>
                      <Input type="password" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <Button type="submit" className="w-full">
                Sign in
              </Button>

              <div className="flex items-center justify-between text-sm">
                <Link href="/forgot-password" className="underline hover:text-primary">
                  Forgot password?
                </Link>
                {canResendVerification ? (
                  <Button
                    type="button"
                    variant="link"
                    className="h-auto p-0"
                    onClick={resendVerification}
                  >
                    Resend verification
                  </Button>
                ) : null}
              </div>
            </form>
          </Form>
        </CardContent>
        <CardFooter className="justify-center">
          <p className="text-sm text-muted-foreground">
            Don&apos;t have an account?{" "}
            <Link href="/register" className="underline hover:text-primary">
              Sign up
            </Link>
          </p>
        </CardFooter>
      </Card>
    </div>
  );
}

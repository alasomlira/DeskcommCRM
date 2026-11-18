import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

/**
 * Entrada da instalação.
 *
 * Quem tem sessão segue para o painel. Quem não tem é levado diretamente ao
 * login: a landing page pública não faz parte desta instalação white-label.
 *
 * `getUser()` e nunca `getSession()`: o redirecionamento só vale para sessão que
 * o servidor de autenticação confirmou.
 */
export const dynamic = "force-dynamic";

export default async function HomePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) redirect("/app");
  redirect("/login");
}

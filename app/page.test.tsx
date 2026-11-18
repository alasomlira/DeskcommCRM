import { beforeEach, describe, expect, it, vi } from "vitest";

const cena = vi.hoisted(() => ({
  usuario: null as { id: string } | null,
}));

vi.mock("next/navigation", () => ({
  redirect: vi.fn((destino: string) => {
    throw new Error(`NEXT_REDIRECT:${destino}`);
  }),
}));
vi.mock("@/lib/supabase/server", () => ({
  createClient: async () => ({
    auth: { getUser: async () => ({ data: { user: cena.usuario } }) },
  }),
}));
import HomePage from "./page";

async function abrirInicio() {
  await HomePage();
}

beforeEach(() => {
  cena.usuario = null;
});

describe("/ — entrada da instalação", () => {
  it("sem sessão: redireciona diretamente ao login", async () => {
    await expect(abrirInicio()).rejects.toThrow("NEXT_REDIRECT:/login");
  });

  it("com sessão: segue direto para o painel, como sempre foi", async () => {
    cena.usuario = { id: "11111111-1111-4111-8111-111111111111" };
    await expect(abrirInicio()).rejects.toThrow("NEXT_REDIRECT:/app");
  });
});

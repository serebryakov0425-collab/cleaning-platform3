import { useTranslations } from "next-intl";
import { setRequestLocale } from "next-intl/server";
import { Button } from "@/components/ui/button";

type Props = {
  params: Promise<{ locale: string }>;
};

export default async function HomePage({ params }: Props) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = useTranslations("HomePage");

  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col items-center justify-center gap-6 px-4 text-center">
      <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
        {t("title")}
      </h1>
      <p className="text-lg text-muted-foreground">{t("subtitle")}</p>
      {/*
        Intentionally disabled: the calculator and lead form are not
        implemented yet (Phase 5/6). No fake CTA behaviour is wired up.
      */}
      <Button type="button" disabled aria-disabled="true" size="lg">
        {t("cta")}
      </Button>
      <p className="text-sm text-muted-foreground">{t("comingSoon")}</p>
    </main>
  );
}

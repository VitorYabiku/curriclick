import React from "react";
import { Sparkles, TrendingUp, Target } from "lucide-react";
import { Card, CardContent } from "./ui/card";

type AiRecommendationsProps = {
  description: string;
};

export function AIRecommendations({ description }: AiRecommendationsProps) {
  return (
    <Card className="bg-gradient-to-br from-primary/10 via-accent/5 to-background border-primary/20">
      <CardContent className="p-6">
        <div className="flex items-start gap-4">
          <div className="p-3 rounded-lg bg-primary/10">
            <Sparkles className="h-6 w-6 text-primary" />
          </div>
          <div className="flex-1 space-y-3">
            <h3 className="text-lg font-semibold text-foreground flex items-center gap-2">
              {"AI-Powered Insights"}
            </h3>
            <p className="text-sm text-muted-foreground leading-relaxed">
              {description}
            </p>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2">
              <div className="flex items-center gap-2 text-sm">
                <TrendingUp className="h-4 w-4 text-accent" />
                <span className="text-foreground">
                  {"95% match with top position"}
                </span>
              </div>
              <div className="flex items-center gap-2 text-sm">
                <Target className="h-4 w-4 text-accent" />
                <span className="text-foreground">
                  {"3 companies actively hiring"}
                </span>
              </div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

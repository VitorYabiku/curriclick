import React from "react";
import {
  // MapPin,
  // Briefcase,
  // DollarSign,
  // Clock,
  Sparkles,
  ChevronDown,
  // AlertCircle,
  // Plus,
} from "lucide-react";
import { Card, CardContent, CardFooter, CardHeader } from "./ui/card";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
// import {
//   Tooltip,
//   TooltipContent,
//   TooltipProvider,
//   TooltipTrigger,
// } from "./ui/tooltip";
// import {
//   Accordion,
//   AccordionContent,
//   AccordionItem,
//   AccordionTrigger,
// } from "./ui/accordion";
import { useState } from "react";
import type { JobCardData } from "../types";

type JobCardProps = {
  job: JobCardData;
  matchScore: number;
};

export function JobCard({ job, matchScore }: JobCardProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  const getMatchColor = (score: number) => {
    if (score >= 90) return "bg-primary text-primary-foreground";
    if (score >= 70) return "bg-accent text-accent-foreground";
    if (score < 0) return "bg-destructive/10 text-destructive";
    return "bg-secondary text-secondary-foreground";
  };

  const formatScore = (score: number) => {
    if (!Number.isFinite(score)) return "0";
    const fixed = score.toFixed(1);
    const normalized = fixed.replace(/\.0$/, "");
    return normalized === "-0" ? "0" : normalized;
  };

  const badgeLabel = matchScore >= 0 ? "Compatível" : "Incompatível";
  const displayScore = formatScore(matchScore);

  // const requiredSkills = job.skills.filter((skill) => skill.required);
  // const niceToHaveSkills = job.skills.filter((skill) => !skill.required);

  // Mock values for now - these would come from additional data or calculations
  const companyName = job.company?.name || "Company";

  return (
    <Card
      className="hover:border-primary/50 transition-all duration-200 cursor-pointer overflow-hidden"
      onClick={() => setIsExpanded(!isExpanded)}
    >
      <CardHeader className="pb-2 px-4 pt-4">
        <div className="flex items-start gap-3">
          <div className="relative h-10 w-10 rounded-lg overflow-hidden bg-muted flex-shrink-0" />
          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between gap-2 mb-1">
              <h3 className="text-base font-semibold text-foreground hover:text-primary transition-colors text-balance">
                {job.jobRoleName}
              </h3>
              <ChevronDown
                className={`h-4 w-4 text-muted-foreground transition-transform duration-200 flex-shrink-0 ${
                  isExpanded ? "rotate-180" : ""
                }`}
              />
            </div>
            <p className="text-sm font-medium text-foreground/90 mb-1">
              {companyName}
            </p>
            {/* Optional metadata row if available in the future */}
            {/* <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
              <div className="flex items-center gap-1">
                <MapPin className="h-3 w-3" />
                <span>{job.location}</span>
              </div>
              <div className="flex items-center gap-1">
                <Briefcase className="h-3 w-3" />
                <span>{job.type}</span>
              </div>
              <div className="flex items-center gap-1">
                <DollarSign className="h-3 w-3" />
                <span>{job.salary}</span>
              </div>
              <div className="flex items-center gap-1">
                <Clock className="h-3 w-3" />
                <span>{job.postedDate}</span>
              </div>
            </div> */}
          </div>
        </div>
      </CardHeader>

      <CardContent className="space-y-3 px-4 pb-3">
        <Badge
          className={`${getMatchColor(matchScore)} flex items-center gap-1 w-fit text-xs`}
        >
          <Sparkles className="h-3 w-3" />
          {displayScore}% {badgeLabel}
        </Badge>

        <div
          className={`transition-all duration-150 ${
            isExpanded
              ? "max-h-0 opacity-0 overflow-hidden"
              : "max-h-96 opacity-100"
          }`}
        >
          <div className="flex flex-wrap gap-1.5">
            {/*
            <TooltipProvider>
              {job.skills.slice(0, 6).map((skill, index) => (
                <Tooltip key={`${skill.name}-${index}`} delayDuration={200}>
                  <TooltipTrigger asChild>
                    <Badge
                      variant="outline"
                      className={`cursor-help text-xs ${
                        skill.required
                          ? "bg-destructive/10 text-destructive border-destructive/30"
                          : "bg-primary/10 text-primary border-primary/30"
                      }`}
                    >
                      {skill.name}
                    </Badge>
                  </TooltipTrigger>
                  <TooltipContent side="top" className="max-w-xs">
                    <p className="text-sm">{skill.description}</p>
                  </TooltipContent>
                </Tooltip>
              ))}
            </TooltipProvider>
            */}
          </div>
        </div>

        <div
          className={`transition-all duration-150 ${
            isExpanded
              ? "max-h-[2000px] opacity-100"
              : "max-h-0 opacity-0 overflow-hidden"
          }`}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="space-y-3 pt-3 border-t border-border">
            {/*requiredSkills.length > 0 && (
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <AlertCircle className="h-4 w-4 text-destructive" />
                  <h3 className="text-sm font-semibold text-foreground">
                    Habilidades Obrigatórias
                  </h3>
                  <Badge variant="destructive" className="ml-auto text-xs">
                    {requiredSkills.length}
                  </Badge>
                </div>
                <Accordion
                  type="multiple"
                  className="w-full"
                  defaultValue={requiredSkills.map(
                    (_, index) => `required-${index}`,
                  )}
                >
                  {requiredSkills.map((skill, index) => (
                    <AccordionItem
                      key={`required-${index}`}
                      value={`required-${index}`}
                      className="border-2 border-destructive/20 bg-destructive/5 rounded-lg px-3 mb-1.5"
                    >
                      <AccordionTrigger className="hover:no-underline py-2">
                        <div className="flex items-center gap-2">
                          <Badge
                            variant="destructive"
                            className="font-semibold text-xs"
                          >
                            {skill.fullName}
                          </Badge>
                          <span className="text-xs text-destructive font-medium uppercase tracking-wide">
                            Obrigatório
                          </span>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="pb-2 pt-1">
                        <p className="text-xs text-muted-foreground leading-relaxed">
                          {skill.description}
                        </p>
                      </AccordionContent>
                    </AccordionItem>
                  ))}
                </Accordion>
              </div>
            )*/}

            {/*niceToHaveSkills.length > 0 && (
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <Plus className="h-4 w-4 text-primary" />
                  <h3 className="text-sm font-semibold text-foreground">
                    Habilidades Desejáveis
                  </h3>
                  <Badge
                    variant="secondary"
                    className="ml-auto bg-primary/10 text-primary text-xs"
                  >
                    {niceToHaveSkills.length}
                  </Badge>
                </div>
                <Accordion
                  type="multiple"
                  className="w-full"
                  defaultValue={niceToHaveSkills.map(
                    (_, index) => `nice-${index}`,
                  )}
                >
                  {niceToHaveSkills.map((skill, index) => (
                    <AccordionItem
                      key={`nice-${index}`}
                      value={`nice-${index}`}
                      className="border border-primary/20 bg-primary/5 rounded-lg px-3 mb-1.5"
                    >
                      <AccordionTrigger className="hover:no-underline py-2">
                        <div className="flex items-center gap-2">
                          <Badge
                            variant="secondary"
                            className="font-semibold bg-primary/10 text-primary text-xs"
                          >
                            {skill.fullName}
                          </Badge>
                          <span className="text-xs text-primary font-medium uppercase tracking-wide">
                            Desejável
                          </span>
                        </div>
                      </AccordionTrigger>
                      <AccordionContent className="pb-2 pt-1">
                        <p className="text-xs text-muted-foreground leading-relaxed">
                          {skill.description}
                        </p>
                      </AccordionContent>
                    </AccordionItem>
                  ))}
                </Accordion>
              </div>
            )*/}
            <p className="text-xs text-muted-foreground leading-relaxed">
              {job.description}
            </p>
          </div>
        </div>
      </CardContent>

      <CardFooter className="flex gap-2 px-4 pb-4 pt-2">
        <Button
          className="flex-1"
          variant="default"
          onClick={(e) => e.stopPropagation()}
        >
          <Sparkles className="h-3.5 w-3.5 mr-1.5" />
          {"Candidatar-se Automaticamente"}
        </Button>
        <Button
          className="flex-1 bg-transparent"
          variant="outline"
          onClick={(e) => e.stopPropagation()}
        >
          {"Candidatar-se Manualmente"}
        </Button>
      </CardFooter>
    </Card>
  );
}

// Frontend type mappings based on generated Ash TypeScript types
// This file ensures frontend and backend types stay in sync

import type {
  JobListingResourceSchema,
  JobRequirementResourceSchema,
  CompanyResourceSchema,
  ListJobListingsResult,
  ListJobRequirementsResult,
  ListCompaniesResult,
  ListJobListingsFields,
  ListJobRequirementsFields,
  ListCompaniesFields,
  UUID,
} from "./ash_rpc";

// Base types extracted from Ash schemas
export type BaseJobListing = {
  id: UUID;
  jobRoleName: string;
  jobDescription: string;
  companyId: UUID;
};

export type BaseJobRequirement = {
  id: UUID;
  title: string | null;
  requirementText: string;
  isRequired: boolean;
  jobListingId: UUID;
};

export type BaseCompany = {
  id: UUID;
  name: string;
  industry: string;
  cnpj: string;
  description: string | null;
};

// Company data as returned by the API (subset of full company)
export type CompanyApiData = {
  id: UUID;
  name: string;
  industry: string;
  description: string | null;
};

// Field selections for API calls - mutable arrays to match API requirements
export const JOB_LISTING_FIELDS: Array<
  "id" | "jobRoleName" | "jobDescription" | "companyId"
> = ["id", "jobRoleName", "jobDescription", "companyId"];

export const JOB_REQUIREMENT_FIELDS: Array<
  "id" | "title" | "requirementText" | "isRequired" | "jobListingId"
> = ["id", "title", "requirementText", "isRequired", "jobListingId"];

export const COMPANY_FIELDS: Array<"id" | "name" | "industry" | "description"> =
  ["id", "name", "industry", "description"];

// Type-safe field selections
export type JobListingFieldSelection = typeof JOB_LISTING_FIELDS;
export type JobRequirementFieldSelection = typeof JOB_REQUIREMENT_FIELDS;
export type CompanyFieldSelection = typeof COMPANY_FIELDS;

// API result types using the generated types
export type JobListingsApiResult =
  ListJobListingsResult<JobListingFieldSelection>;
export type JobRequirementsApiResult =
  ListJobRequirementsResult<JobRequirementFieldSelection>;
export type CompaniesApiResult = ListCompaniesResult<CompanyFieldSelection>;

// Frontend UI types derived from the API types
export type JobListingUI = BaseJobListing & {
  jobRequirements?: BaseJobRequirement[];
};

// Result item when selecting jobRequirements via relationship fetching
export type JobListingWithRequirements = BaseJobListing & {
  jobRequirements: BaseJobRequirement[];
};

export type SkillUI = {
  // Short label for chips/pills
  name: string;
  // Full label for detailed view (never truncated)
  fullName: string;
  description: string;
  required: boolean;
};

export type CompanyUI = Pick<
  CompanyApiData,
  "name" | "industry" | "description"
>;

export type JobCardData = BaseJobListing & {
  company?: CompanyUI;
  description: string;
  matchScore?: number;
};

// API response wrapper types
export type PaginatedResult<T> = {
  results: T[];
  hasMore: boolean;
  count: number;
};

// Utility types for transforming API responses to UI data
export type TransformJobRequirementToSkill = (
  requirement: BaseJobRequirement,
) => SkillUI;
export type TransformCompanyToUI = (company: CompanyApiData) => CompanyUI;
export type TransformJobListingToCard = (
  job: BaseJobListing,
  requirements: BaseJobRequirement[],
  company?: CompanyApiData,
) => JobCardData;

// Helper functions for type transformations
export const transformJobRequirementToSkill: TransformJobRequirementToSkill = (
  requirement,
) => {
  const fullName = requirement.title || requirement.requirementText;
  const short =
    fullName.length > 30 ? fullName.substring(0, 30) + "..." : fullName;
  return {
    name: short,
    fullName,
    description: requirement.requirementText,
    required: requirement.isRequired,
  };
};

export const transformCompanyToUI: TransformCompanyToUI = (company) => ({
  name: company.name,
  industry: company.industry,
  description: company.description,
});

export const transformJobListingToCard: TransformJobListingToCard = (
  job,
  requirements,
  company,
) => ({
  id: job.id,
  jobRoleName: job.jobRoleName,
  jobDescription: job.jobDescription,
  companyId: job.companyId,
  skills: requirements.map(transformJobRequirementToSkill),
  company: company ? transformCompanyToUI(company) : undefined,
});

// Field validation helpers using the generated types
export type ValidateFields<
  T extends readonly string[],
  U,
> = T extends readonly (keyof U)[] ? T : never;

// Ensure our field selections are valid against the generated types
type _ValidateJobListingFields = ValidateFields<
  typeof JOB_LISTING_FIELDS,
  JobListingResourceSchema
>;
type _ValidateJobRequirementFields = ValidateFields<
  typeof JOB_REQUIREMENT_FIELDS,
  JobRequirementResourceSchema
>;
type _ValidateCompanyFields = ValidateFields<
  typeof COMPANY_FIELDS,
  CompanyResourceSchema
>;


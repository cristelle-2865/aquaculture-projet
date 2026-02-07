package com.example.aquaculture.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class BassinDTO {
    private Long id;
    private String nom;
    private Integer capaciteMax;
    private String description;
    private Boolean estActif;
    private BigDecimal volume;
    private BigDecimal temperature;
    private BigDecimal ph;
    private Integer nombrePoissons;
    private Integer capaciteRestante;
    private BigDecimal tauxOccupation;
}

// Create DTO
@Data
class BassinCreateDTO {
    private String nom;
    private Integer capaciteMax;
    private String description;
    private BigDecimal volume;
    private BigDecimal temperature;
    private BigDecimal ph;
}

// Statistiques DTO
@Data
class BassinStatsDTO {
    private Long id;
    private String nom;
    private Integer nombrePoissons;
    private Integer capaciteMax;
    private BigDecimal tauxOccupation;
    private Long poissonsAffames;
    private Long poissonsPretAVendre;
    private BigDecimal poidsTotal;
}


package com.felipebagarelli.gymmanager.account.repository;

import com.felipebagarelli.gymmanager.account.entity.AccountToken;
import com.felipebagarelli.gymmanager.account.entity.TokenPurpose;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AccountTokenRepository extends JpaRepository<AccountToken, Long> {
    Optional<AccountToken> findFirstByUserIdAndPurposeAndUsedAtIsNullOrderByCreatedAtDesc(Long userId, TokenPurpose purpose);

    List<AccountToken> findByUserIdAndPurposeAndUsedAtIsNull(Long userId, TokenPurpose purpose);

    Optional<AccountToken> findByTokenHashAndPurpose(String tokenHash, TokenPurpose purpose);
}

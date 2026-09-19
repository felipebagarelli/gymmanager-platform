package com.felipebagarelli.gymmanager.repository;

import com.felipebagarelli.gymmanager.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MemberRepository extends JpaRepository<Member, Long> {

}